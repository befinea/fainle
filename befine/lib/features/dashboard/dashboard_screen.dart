import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../ui/widgets/atoms.dart';
import '../../../ui/widgets/animated_glass_card.dart';
import '../../../ui/widgets/notification_panel.dart';
import '../auth/application/auth_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _supabase = Supabase.instance.client;

  String _totalSales = '...';
  String _productCount = '...';
  String _lowStockCount = '...';
  String _pendingTasks = '...';
  List<Map<String, dynamic>> _recentActivities = [];
  bool _loadingActivities = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchRecentActivities();
  }

  Future<void> _fetchStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get company_id
      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      final companyId = profile['company_id'] as String;

      // Total Sales
      final salesData = await _supabase
          .from('transactions')
          .select('total_amount')
          .eq('company_id', companyId)
          .eq('type', 'sale');
      double totalSales = 0;
      for (final row in salesData) {
        totalSales += (row['total_amount'] as num?)?.toDouble() ?? 0;
      }

      // Product count
      final productsData = await _supabase
          .from('products')
          .select('id')
          .eq('company_id', companyId);

      // Low stock count
      final lowStockData = await _supabase.rpc('count_low_stock', params: {'p_company_id': companyId}).catchError((_) => null);
      int lowStock = 0;
      if (lowStockData != null && lowStockData is int) {
        lowStock = lowStockData;
      } else {
        // Fallback: manual query
        try {
          final stockRows = await _supabase
              .from('stock_levels')
              .select('quantity, min_threshold, location_id, locations!inner(company_id)')
              .lte('quantity', 5); // rough fallback
          lowStock = (stockRows as List).where((r) {
            final q = (r['quantity'] as num?)?.toInt() ?? 0;
            final t = (r['min_threshold'] as num?)?.toInt() ?? 5;
            return q <= t;
          }).length;
        } catch (_) {}
      }

      // Pending tasks
      int pendingCount = 0;
      try {
        final tasksData = await _supabase
            .from('tasks')
            .select('id')
            .eq('company_id', companyId)
            .eq('status', 'pending');
        pendingCount = (tasksData as List).length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _totalSales = '${totalSales.toStringAsFixed(0)} د';
          _productCount = '${(productsData as List).length}';
          _lowStockCount = '$lowStock';
          _pendingTasks = '$pendingCount';
        });
      }
    } catch (e) {
      debugPrint('Dashboard stats error: $e');
      if (mounted) {
        setState(() {
          _totalSales = '0 د';
          _productCount = '0';
          _lowStockCount = '0';
          _pendingTasks = '0';
        });
      }
    }
  }

  Future<void> _fetchRecentActivities() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      final companyId = profile['company_id'] as String;

      final data = await _supabase
          .from('transactions')
          .select('id, type, total_amount, created_at, notes, location_id, performed_by')
          .eq('company_id', companyId)
          .order('created_at', ascending: false)
          .limit(10);

      final List<Map<String, dynamic>> activities = [];
      for (final tx in data) {
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
        activities.add({
          'type': tx['type'] ?? 'sale',
          'total_amount': tx['total_amount'],
          'created_at': tx['created_at'] ?? '',
          'location_name': locationName,
          'performed_by': performerName,
        });
      }

      if (mounted) {
        setState(() {
          _recentActivities = activities;
          _loadingActivities = false;
        });
      }
    } catch (e) {
      debugPrint('Dashboard activities error: $e');
      if (mounted) setState(() => _loadingActivities = false);
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'sale': return 'بيع';
      case 'import': return 'وارد';
      case 'export': return 'صادر';
      case 'transfer_out': return 'نقل صادر';
      case 'transfer_in': return 'نقل وارد';
      case 'adjustment': return 'تعديل';
      default: return type;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'sale': return Icons.shopping_cart;
      case 'import': return Icons.download;
      case 'export': return Icons.upload;
      case 'transfer_out': return Icons.arrow_forward;
      case 'transfer_in': return Icons.arrow_back;
      default: return Icons.swap_horiz;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'sale': return AppColors.success;
      case 'import': return Colors.blue;
      case 'export': return Colors.orange;
      case 'transfer_out': return Colors.purple;
      case 'transfer_in': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _formatTime12h(String createdAt) {
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
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final theme = Theme.of(context);
    final userState = ref.watch(authProvider);
    final userRole = userState.user?.role ?? 'cashier';
    
    return Scaffold(
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
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                title: Text('لوحة التحكم', style: theme.textTheme.titleLarge),
                floating: true,
                actions: [
                  AnimatedGlassCard(
                    padding: const EdgeInsets.all(8),
                    color: theme.colorScheme.surface,
                    onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => RotationTransition(
                        turns: anim,
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        key: ValueKey(isDark),
                        color: isDark ? Colors.amber : Colors.indigo,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedGlassCard(
                    padding: const EdgeInsets.all(8),
                    color: theme.colorScheme.surface,
                    onTap: () => NotificationPanel.show(context),
                    child: Icon(Icons.notifications_outlined, color: theme.colorScheme.onSurface),
                  ),
                  AnimatedGlassCard(
                    padding: const EdgeInsets.all(8),
                    color: theme.colorScheme.surface,
                    onTap: () => context.push('/settings'),
                    child: Icon(Icons.settings_rounded, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText('مرحباً بك، ${userState.user?.name ?? (userRole == 'supplier' ? 'المورد' : 'المدير')}', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      AppText('إليك نظرة عامة على النشاط', style: theme.textTheme.bodyMedium, color: AppColors.textSecondaryDark),
                      const SizedBox(height: 24),

                      // Stats Grid — REAL DATA
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.4,
                        children: [
                          _StatCard(title: 'إجمالي المبيعات', value: _totalSales, icon: Icons.attach_money, color: AppColors.primary),
                          _StatCard(title: 'المنتجات', value: _productCount, icon: Icons.inventory_2, color: AppColors.secondary),
                          _StatCard(title: 'مخزون منخفض', value: _lowStockCount, icon: Icons.warning_amber, color: AppColors.error),
                          _StatCard(title: 'مهام معلقة', value: _pendingTasks, icon: Icons.task_alt, color: AppColors.success),
                        ],
                      ),

                      const SizedBox(height: 32),

                      AppText('إجراءات سريعة', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                        children: [
                          if (userRole != 'supplier')
                            _QuickAction(icon: Icons.add_box_rounded, label: 'إضافة مورد', color: AppColors.primary, onTap: () => context.push('/operations/suppliers/create')),
                          _QuickAction(icon: Icons.point_of_sale, label: 'بيع', color: AppColors.success, onTap: () => context.go('/pos')),
                          _QuickAction(icon: Icons.download_rounded, label: 'وارد', color: Colors.blue, onTap: () => context.push('/operations/transaction/create?type=import')),
                          _QuickAction(icon: Icons.upload_rounded, label: 'صادر', color: Colors.orange, onTap: () => context.push('/operations/transaction/create?type=export')),
                          if (userRole != 'supplier')
                            _QuickAction(icon: Icons.swap_horiz, label: 'نقل', color: Colors.purple, onTap: () => context.push('/operations/transaction/create?type=transfer')),
                          if (userRole != 'supplier')
                            _QuickAction(icon: Icons.people_alt, label: 'موردون', color: Colors.teal, onTap: () => context.go('/operations?tab=suppliers')),
                          _QuickAction(icon: Icons.print_rounded, label: 'طباعة BC', color: Colors.indigo, onTap: () => context.push('/barcode-print')),
                          _QuickAction(icon: Icons.analytics_rounded, label: 'تقارير', color: Colors.brown, onTap: () => context.go('/reports')),
                        ],
                      ),

                      const SizedBox(height: 32),

                      AppText('آخر النشاطات', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),

                      // REAL ACTIVITIES
                      if (_loadingActivities)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else if (_recentActivities.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text('لا توجد نشاطات بعد', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(_recentActivities.length, (i) {
                          final tx = _recentActivities[i];
                          final type = tx['type'] as String? ?? 'sale';
                          final amount = (tx['total_amount'] as num?)?.toDouble() ?? 0;
                          final locationName = tx['location_name'] as String? ?? '';
                          final performedBy = tx['performed_by'] as String? ?? '';
                          final createdAt = tx['created_at'] as String? ?? '';
                          final timeStr = _formatTime12h(createdAt);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AnimatedGlassCard(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              onTap: () {},
                              child: _ActivityTile(
                                title: '${_typeLabel(type)} ${amount > 0 ? '• ${amount.toStringAsFixed(0)} د' : ''}',
                                subtitle: '$locationName ${performedBy.isNotEmpty ? '• $performedBy' : ''} ${timeStr.isNotEmpty ? '• $timeStr' : ''}',
                                icon: _typeIcon(type),
                                color: _typeColor(type),
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 100), // FAB spacing
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              Icon(Icons.arrow_outward_rounded, color: Colors.grey.withOpacity(0.5), size: 18),
            ],
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassCard(
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14)
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  const _ActivityTile({required this.title, required this.subtitle, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
