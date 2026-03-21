import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _filterAction;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser!;
      final profile = await _supabase
          .from('profiles')
          .select('company_id')
          .eq('id', user.id)
          .single();
      final companyId = profile['company_id'] as String;

      var query = _supabase
          .from('audit_logs')
          .select('*, profiles!audit_logs_user_id_fkey(full_name)')
          .eq('company_id', companyId);

      if (_filterAction != null && _filterAction!.isNotEmpty) {
        query = query.eq('action', _filterAction!);
      }

      final data = await query.order('created_at', ascending: false).limit(50);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading audit logs: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _actionIcon(String action) {
    if (action.contains('created')) return Icons.add_circle_outlined;
    if (action.contains('updated')) return Icons.edit_outlined;
    if (action.contains('deleted')) return Icons.delete_outlined;
    if (action.contains('sale')) return Icons.shopping_cart_rounded;
    if (action.contains('invited')) return Icons.person_add_rounded;
    if (action.contains('stock')) return Icons.inventory_rounded;
    if (action.contains('transfer')) return Icons.swap_horiz_rounded;
    if (action.contains('import')) return Icons.download_rounded;
    if (action.contains('export')) return Icons.upload_rounded;
    return Icons.info_outline_rounded;
  }

  Color _actionColor(String action) {
    if (action.contains('created')) return AppColors.success;
    if (action.contains('sale')) return AppColors.primary;
    if (action.contains('deleted')) return AppColors.error;
    if (action.contains('invited')) return Colors.blue;
    if (action.contains('updated')) return Colors.orange;
    if (action.contains('stock') || action.contains('import')) return Colors.teal;
    return Colors.grey;
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'warehouse_created': return 'إنشاء مخزن';
      case 'store_created': return 'إنشاء متجر';
      case 'product_created': return 'إضافة منتج';
      case 'product_updated': return 'تعديل منتج';
      case 'product_deleted': return 'حذف منتج';
      case 'sale_completed': return 'عملية بيع';
      case 'employee_invited': return 'دعوة موظف';
      case 'stock_adjusted': return 'تعديل مخزون';
      case 'transaction_import': return 'وارد';
      case 'transaction_export': return 'صادر';
      case 'transaction_transfer': return 'نقل';
      default: return action.replaceAll('_', ' ');
    }
  }

  String _formatTime(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
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
      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'م' : 'ص';
      if (hour == 0) hour = 12;
      if (hour > 12) hour -= 12;
      return '$ago • $hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل النشاطات', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              setState(() => _filterAction = value);
              _loadLogs();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('كل النشاطات')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'sale_completed', child: Text('🛒 المبيعات')),
              const PopupMenuItem(value: 'product_created', child: Text('📦 إضافة منتج')),
              const PopupMenuItem(value: 'warehouse_created', child: Text('🏭 إنشاء مخزن')),
              const PopupMenuItem(value: 'store_created', child: Text('🏪 إنشاء متجر')),
              const PopupMenuItem(value: 'employee_invited', child: Text('👤 دعوات')),
              const PopupMenuItem(value: 'stock_adjusted', child: Text('📊 تعديل مخزون')),
            ],
          ),
          IconButton(
            onPressed: _loadLogs,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.background.withOpacity(0.9),
              theme.colorScheme.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('لا توجد نشاطات مسجلة', style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                          if (_filterAction != null) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() => _filterAction = null);
                                _loadLogs();
                              },
                              child: const Text('إزالة الفلتر'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final action = log['action'] as String? ?? '';
                        final createdAt = log['created_at'] as String? ?? '';
                        final profileData = log['profiles'];
                        final userName = profileData is Map ? (profileData['full_name'] as String? ?? 'مستخدم') : 'مستخدم';
                        final details = log['details'] as Map<String, dynamic>?;
                        final entityType = log['entity_type'] as String? ?? '';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AnimatedGlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _actionColor(action).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_actionIcon(action), color: _actionColor(action), size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _actionLabel(action),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const Spacer(),
                                          Text(
                                            _formatTime(createdAt),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'بواسطة: $userName',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      ),
                                      if (details != null && details.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        ...details.entries
                                            .where((e) => e.value != null && e.value.toString().isNotEmpty)
                                            .take(3)
                                            .map((e) => Text(
                                                  '${e.key}: ${e.value}',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                                )),
                                      ],
                                      if (entityType.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'نوع: $entityType',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                        ),
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
      ),
    );
  }
}
