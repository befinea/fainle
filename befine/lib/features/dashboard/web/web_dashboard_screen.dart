import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../ui/widgets/atoms.dart';
import '../../auth/application/auth_service.dart';

class WebDashboardScreen extends ConsumerStatefulWidget {
  const WebDashboardScreen({super.key});

  @override
  ConsumerState<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends ConsumerState<WebDashboardScreen> {
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

      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      final companyId = profile['company_id'] as String;

      final salesData = await _supabase.from('transactions').select('total_amount').eq('company_id', companyId).eq('type', 'sale');
      double totalSales = 0;
      for (final row in salesData) totalSales += (row['total_amount'] as num?)?.toDouble() ?? 0;

      final productsData = await _supabase.from('products').select('id').eq('company_id', companyId);

      int lowStock = 0;
      try {
        final lowStockData = await _supabase.rpc('count_low_stock', params: {'p_company_id': companyId});
        if (lowStockData != null && lowStockData is int) lowStock = lowStockData;
      } catch (_) {}

      int pendingCount = 0;
      try {
        final tasksData = await _supabase.from('tasks').select('id').eq('company_id', companyId).eq('status', 'pending');
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
      if (mounted) setState(() { _totalSales = '0'; _productCount = '0'; _lowStockCount = '0'; _pendingTasks = '0'; });
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
        String locationName = ''; String performerName = '';
        try {
          if (tx['location_id'] != null) {
            final loc = await _supabase.from('locations').select('name').eq('id', tx['location_id']).maybeSingle();
            locationName = loc?['name'] as String? ?? '';
          }
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

      if (mounted) setState(() { _recentActivities = activities; _loadingActivities = false; });
    } catch (e) {
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

  String _formatTime(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userState = ref.watch(authProvider);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Dashboard Area
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header (Search & Actions)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText('نظرة عامة للويب', style: theme.textTheme.titleLarge),
                          AppText('مرحباً بك، ${userState.user?.name ?? 'المدير'}', style: theme.textTheme.bodyLarge, color: AppColors.textSecondaryDark),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 300,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                            ),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'بحث في النظام...',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                            style: IconButton.styleFrom(backgroundColor: theme.colorScheme.surface, padding: const EdgeInsets.all(12)),
                          ),
                          const SizedBox(width: 16),
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary,
                            child: AppText(userState.user?.name?.substring(0, 1) ?? 'م', color: Colors.white),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Admin KPI Cards
                  Row(
                    children: [
                      Expanded(child: _buildKpiCard(context, 'إجمالي الإيرادات', _totalSales, Icons.trending_up, Colors.green)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildKpiCard(context, 'المنتجات المسجلة', _productCount, Icons.inventory_2_outlined, Colors.blue)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildKpiCard(context, 'نواقص المخزون', _lowStockCount, Icons.warning_amber_rounded, Colors.orange)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildKpiCard(context, 'المهام المعلقة', _pendingTasks, Icons.task_alt, Colors.purple)),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Data Table for Recent Activities (Web specific instead of list tiles)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppText('أحدث العمليات', style: theme.textTheme.titleMedium),
                            TextButton.icon(onPressed: () => context.go('/operations'), icon: const Icon(Icons.arrow_forward_rounded), label: const Text('عرض الكل'))
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_loadingActivities)
                          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                        else if (_recentActivities.isEmpty)
                          const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('لا توجد نشاطات مسجلة')))
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                              columns: const [
                                DataColumn(label: Text('نوع العملية')),
                                DataColumn(label: Text('التاريخ والوقت')),
                                DataColumn(label: Text('القيمة')),
                                DataColumn(label: Text('المخزن / الفرع')),
                                DataColumn(label: Text('بواسطة')),
                              ],
                              rows: _recentActivities.map((tx) {
                                final type = tx['type'] as String? ?? 'sale';
                                final amount = (tx['total_amount'] as num?)?.toDouble() ?? 0;
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(color: _typeColor(type).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                        child: Text(_typeLabel(type), style: TextStyle(color: _typeColor(type), fontWeight: FontWeight.bold)),
                                      )
                                    ),
                                    DataCell(Text(_formatTime(tx['created_at'] as String? ?? ''))),
                                    DataCell(Text(amount > 0 ? '${amount.toStringAsFixed(0)} د.ع' : '-')),
                                    DataCell(Text(tx['location_name'] as String? ?? '-')),
                                    DataCell(Text(tx['performed_by'] as String? ?? '-')),
                                  ]
                                );
                              }).toList(),
                            ),
                          )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Right/Left Sidebar for Quick Actions / Secondary Info
          Container(
            width: 320,
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('إجراءات لوحة التحكم', style: theme.textTheme.titleMedium),
                const SizedBox(height: 24),
                _buildSidebarActionBtn(context, 'عملية بيع سريعة', Icons.add_shopping_cart, AppColors.success, () => context.go('/pos')),
                const SizedBox(height: 12),
                _buildSidebarActionBtn(context, 'تسجيل بضاعة واردة', Icons.download_rounded, Colors.blue, () => context.push('/operations/transaction/create?type=import')),
                const SizedBox(height: 12),
                _buildSidebarActionBtn(context, 'نقل مخزون', Icons.swap_horiz, Colors.purple, () => context.push('/operations/transaction/create?type=transfer')),
                const SizedBox(height: 12),
                _buildSidebarActionBtn(context, 'إضافة مورد', Icons.person_add_rounded, Colors.teal, () => context.push('/operations/suppliers/create')),
                
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 32),
                      const SizedBox(height: 12),
                      const Text('هل تحتاج إلى مساعدة؟', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('فريق الدعم الفني متاح دائمًا للإجابة على التساؤلات', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: (){}, child: const Text('اتصل بالدعم'))
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color),
              ),
              const Icon(Icons.more_vert_rounded, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildSidebarActionBtn(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
