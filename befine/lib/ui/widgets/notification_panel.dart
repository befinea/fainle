import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import 'animated_glass_card.dart';

class NotificationPanel extends StatefulWidget {
  const NotificationPanel({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const NotificationPanel(),
    );
  }

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() { _loading = false; _errorMsg = 'لم يتم تسجيل الدخول'; });
        return;
      }

      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      final companyId = profile['company_id'] as String;

      // Fetch recent transactions — use performed_by!inner for the FK join
      List<dynamic> txData = [];
      try {
        txData = await _supabase
            .from('transactions')
            .select('id, type, total_amount, created_at, notes, location_id, performed_by')
            .eq('company_id', companyId)
            .order('created_at', ascending: false)
            .limit(20);
      } catch (e) {
        debugPrint('TX fetch error: $e');
      }

      // Manually fetch location names and performer names
      final combined = <Map<String, dynamic>>[];

      for (final tx in txData) {
        String locationName = '';
        String performerName = '';

        try {
          if (tx['location_id'] != null) {
            final loc = await _supabase.from('locations').select('name').eq('id', tx['location_id']).maybeSingle();
            locationName = loc?['name'] as String? ?? '';
          }
        } catch (_) {}

        try {
          if (tx['performed_by'] != null) {
            final perf = await _supabase.from('profiles').select('full_name').eq('id', tx['performed_by']).maybeSingle();
            performerName = perf?['full_name'] as String? ?? '';
          }
        } catch (_) {}

        combined.add({
          'type': tx['type'] as String? ?? 'sale',
          'total_amount': tx['total_amount'],
          'location_name': locationName,
          'performed_by': performerName,
          'notes': tx['notes'] ?? '',
          'created_at': tx['created_at'] ?? '',
        });
      }

      // Fetch low stock alerts
      try {
        final stockData = await _supabase
            .from('stock_levels')
            .select('quantity, min_threshold, product_id, location_id')
            .limit(100);

        for (final row in stockData) {
          final q = (row['quantity'] as num?)?.toInt() ?? 0;
          final t = (row['min_threshold'] as num?)?.toInt() ?? 5;
          if (q <= t) {
            // Check if location belongs to company
            String productName = 'منتج';
            String locName = '';
            bool sameCompany = false;
            try {
              final loc = await _supabase.from('locations').select('name, company_id').eq('id', row['location_id']).maybeSingle();
              if (loc != null && loc['company_id'] == companyId) {
                sameCompany = true;
                locName = loc['name'] as String? ?? '';
              }
            } catch (_) {}
            if (!sameCompany) continue;

            try {
              final prod = await _supabase.from('products').select('name').eq('id', row['product_id']).maybeSingle();
              productName = prod?['name'] as String? ?? 'منتج';
            } catch (_) {}

            combined.insert(0, {
              'type': 'low_stock',
              'product_name': productName,
              'location_name': locName,
              'quantity': q,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            });
          }
        }
      } catch (e) {
        debugPrint('Low stock fetch error: $e');
      }

      if (mounted) {
        setState(() {
          _notifications = combined;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Notifications error: $e');
      if (mounted) setState(() { _loading = false; _errorMsg = 'خطأ في تحميل الإشعارات'; });
    }
  }

  String _getTitle(Map<String, dynamic> item) {
    final type = item['type'] as String;
    switch (type) {
      case 'low_stock': return 'تنبيه: مخزون منخفض';
      case 'sale': return 'عملية بيع جديدة';
      case 'import': return 'عملية استلام (وارد)';
      case 'export': return 'عملية تصدير (صادر)';
      case 'transfer_out': return 'عملية نقل صادر';
      case 'transfer_in': return 'عملية نقل وارد';
      case 'adjustment': return 'تعديل مخزون';
      default: return 'نشاط جديد';
    }
  }

  String _getSubtitle(Map<String, dynamic> item) {
    final type = item['type'] as String;
    if (type == 'low_stock') {
      return '${item['product_name']} وصل إلى ${item['quantity']} وحدات في ${item['location_name']}';
    }
    final location = item['location_name'] as String? ?? '';
    final by = item['performed_by'] as String? ?? '';
    final amount = (item['total_amount'] as num?)?.toDouble() ?? 0;
    String text = '';
    if (location.isNotEmpty) text += location;
    if (by.isNotEmpty) text += ' • بواسطة $by';
    if (amount > 0 && type == 'sale') text += ' • ${amount.toStringAsFixed(0)} د';
    return text.isEmpty ? 'تفاصيل غير متوفرة' : text;
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'low_stock': return Icons.warning_amber_rounded;
      case 'sale': return Icons.shopping_cart_rounded;
      case 'import': return Icons.download_done_rounded;
      case 'export': return Icons.upload_rounded;
      case 'transfer_out': return Icons.arrow_forward_rounded;
      case 'transfer_in': return Icons.arrow_back_rounded;
      default: return Icons.swap_horiz_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'low_stock': return AppColors.error;
      case 'sale': return AppColors.success;
      case 'import': return Colors.blue;
      case 'export': return Colors.orange;
      case 'transfer_out': return Colors.purple;
      case 'transfer_in': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _formatTime(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      // Time ago
      String ago = '';
      if (diff.inMinutes < 1) {
        ago = 'الآن';
      } else if (diff.inMinutes < 60) {
        ago = 'منذ ${diff.inMinutes} دقيقة';
      } else if (diff.inHours < 24) {
        ago = 'منذ ${diff.inHours} ساعة';
      } else {
        ago = 'منذ ${diff.inDays} يوم';
      }

      // 12-hour format
      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'م' : 'ص';
      if (hour == 0) hour = 12;
      if (hour > 12) hour -= 12;

      final date = '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
      return '$ago • $date $hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('التنبيهات', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMsg != null
                      ? Center(child: Text(_errorMsg!, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)))
                      : _notifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text('لا توجد إشعارات حالياً', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: controller,
                              padding: const EdgeInsets.all(20),
                              itemCount: _notifications.length,
                              itemBuilder: (context, i) {
                                final item = _notifications[i];
                                final type = item['type'] as String;
                                final time = _formatTime(item['created_at'] as String? ?? '');

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: AnimatedGlassCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: _getColor(type).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(_getIcon(type), color: _getColor(type), size: 24),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(_getTitle(item), style: const TextStyle(fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(
                                                _getSubtitle(item),
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (time.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(time, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
