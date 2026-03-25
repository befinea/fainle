import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../ui/widgets/animated_glass_card.dart';
import '../../../ui/widgets/notification_panel.dart';
import '../../../ui/widgets/animated_counter.dart';
import '../../../ui/widgets/shimmer_loading.dart';
import '../../../ui/widgets/glass_refresh_indicator.dart';
import '../../../ui/widgets/gradient_border_card.dart';
import '../../../core/utils/haptic_helper.dart';
import '../auth/application/auth_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  String _totalSales = '...';
  String _productCount = '...';
  String _lowStockCount = '...';
  String _pendingTasks = '...';
  String _subscriptionPlan = '';
  String? _companyId;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _loadingActivities = true;

  // Staggered animation controller
  late AnimationController _staggerController;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();

    // Setup staggered animation (6 items: 4 stats + greeting + actions)
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimations = List.generate(6, (i) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOut)),
      );
    });

    _slideAnimations = List.generate(6, (i) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOutCubic)),
      );
    });

    _staggerController.forward();
    _fetchStats();
    _fetchRecentActivities();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get company_id
      final profile = await _supabase.from('profiles').select('company_id').eq('id', user.id).single();
      final companyId = profile['company_id'] as String;
      if (mounted) setState(() => _companyId = companyId);

      // Fetch company plan
      try {
        final companyData = await _supabase.from('companies').select('subscription_plan').eq('id', companyId).single();
        if (mounted) {
          setState(() => _subscriptionPlan = companyData['subscription_plan'] as String? ?? 'free');
        }
      } catch (_) {}

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
          _totalSales = '${totalSales.toStringAsFixed(0)}';
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
    final userState = ref.watch(authProvider);
    final userRole = userState.user?.role ?? 'cashier';
    final isSuperAdmin = _companyId == '00000000-0000-0000-0000-000000000001';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        return Scaffold(
          body: isDesktop
              ? _buildDesktop(context, isDark, userRole, isSuperAdmin)
              : _buildMobile(context, isDark, userRole, isSuperAdmin),
        );
      },
    );
  }

  Widget _buildTopBarControls(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedGlassCard(
          padding: const EdgeInsets.all(10),
          borderRadius: 12,
          onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => RotationTransition(turns: anim, child: FadeTransition(opacity: anim, child: child)),
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(isDark),
              color: isDark ? Colors.amber : Colors.indigo,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedGlassCard(
          padding: const EdgeInsets.all(10),
          borderRadius: 12,
          onTap: () => NotificationPanel.show(context),
          child: Icon(Icons.notifications_outlined, color: isDark ? Colors.white : Colors.black87, size: 22),
        ),
        const SizedBox(width: 8),
        AnimatedGlassCard(
          padding: const EdgeInsets.all(10),
          borderRadius: 12,
          onTap: () => context.push('/settings'),
          child: Icon(Icons.settings_rounded, color: isDark ? Colors.white : Colors.black87, size: 22),
        ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context, bool isDark, String userRole, bool isSuperAdmin) {
    return Column(
      children: [
        // TopAppBar
        Container(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 16),
          decoration: BoxDecoration(
              color: isDark ? const Color(0xff0f172a).withOpacity(0.4) : Colors.white.withOpacity(0.6),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.05), blurRadius: 40, offset: const Offset(0, 20)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20)],
                      ),
                      child: const Icon(Icons.dashboard_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text('لوحة التحكم', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  ],
                ),
                _buildTopBarControls(isDark),
              ],
            ),
          ),

          Expanded(
            child: GlassRefreshIndicator(
              onRefresh: () async {
                HapticHelper.lightTap();
                _staggerController.reset();
                await Future.wait([_fetchStats(), _fetchRecentActivities()]);
                _staggerController.forward();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                children: [
                  // Stagger 0: Greeting
                  FadeTransition(
                    opacity: _fadeAnimations[0],
                    child: SlideTransition(
                      position: _slideAnimations[0],
                      child: _buildGreeting(userRole, isDark),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stagger 1-4: Stats cards
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.3,
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimations[1],
                        child: SlideTransition(
                          position: _slideAnimations[1],
                          child: _StatCard(title: 'إجمالي المبيعات', value: _totalSales, icon: Icons.attach_money, color: AppColors.primary, suffix: ' د', useGradientBorder: true),
                        ),
                      ),
                      FadeTransition(
                        opacity: _fadeAnimations[2],
                        child: SlideTransition(
                          position: _slideAnimations[2],
                          child: _StatCard(title: 'المنتجات', value: _productCount, icon: Icons.inventory_2, color: AppColors.secondary),
                        ),
                      ),
                      FadeTransition(
                        opacity: _fadeAnimations[3],
                        child: SlideTransition(
                          position: _slideAnimations[3],
                          child: _StatCard(title: 'مخزون منخفض', value: _lowStockCount, icon: Icons.warning_amber, color: AppColors.error),
                        ),
                      ),
                      FadeTransition(
                        opacity: _fadeAnimations[4],
                        child: SlideTransition(
                          position: _slideAnimations[4],
                          child: _StatCard(title: 'مهام معلقة', value: _pendingTasks, icon: Icons.task_alt, color: AppColors.success),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _fadeAnimations[5],
                    child: SlideTransition(
                      position: _slideAnimations[5],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إجراءات سريعة', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          GridView.count(
                            crossAxisCount: 4,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                            children: _buildQuickActions(userRole, isSuperAdmin),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text('آخر النشاطات', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildActivitiesList(),
                ],
              ),
            ),
          ),
        ],
      );
  }

  Widget _buildDesktop(BuildContext context, bool isDark, String userRole, bool isSuperAdmin) {
    return Column(
      children: [
        // Desktop Top Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('لوحة التحكم الخاصة بك', style: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
              _buildTopBarControls(isDark),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(48),
            children: [
              _buildGreeting(userRole, isDark),
              const SizedBox(height: 32),

               // Desktop Stats 4x1
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: 2.2,
                children: [
                  _StatCard(title: 'إجمالي المبيعات', value: _totalSales, icon: Icons.attach_money, color: AppColors.primary),
                  _StatCard(title: 'المنتجات', value: _productCount, icon: Icons.inventory_2, color: AppColors.secondary),
                  _StatCard(title: 'مخزون منخفض', value: _lowStockCount, icon: Icons.warning_amber, color: AppColors.error),
                  _StatCard(title: 'مهام معلقة', value: _pendingTasks, icon: Icons.task_alt, color: AppColors.success),
                ],
              ),

              const SizedBox(height: 48),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Real Activities (70%)
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('آخر النشاطات', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        _buildActivitiesList(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  // Quick Actions (30%)
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إجراءات سريعة', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.0,
                          children: _buildQuickActions(userRole, isSuperAdmin),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting(String userRole, bool isDark) {
    final userState = ref.watch(authProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('مرحباً بك، ${userState.user?.name ?? (userRole == 'supplier' ? 'المورد' : 'المدير')}', 
            style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (_subscriptionPlan.isNotEmpty && _subscriptionPlan != 'free' && userRole == 'admin') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _subscriptionPlan == 'premium' ? [Colors.amber.shade600, Colors.orange.shade700] : [Colors.blue.shade600, Colors.blue.shade800],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: (_subscriptionPlan == 'premium' ? Colors.amber : Colors.blue).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_subscriptionPlan == 'premium' ? Icons.workspace_premium_rounded : Icons.diamond_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(_subscriptionPlan == 'premium' ? 'الخطة الذهبية' : 'الخطة الاحترافية', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text('إليك نظرة عامة على نشاط النظام اليوم', 
            style: GoogleFonts.inter(fontSize: 14, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
      ],
    );
  }

  List<Widget> _buildQuickActions(String userRole, bool isSuperAdmin) {
    return [
      if (userRole != 'supplier' && isSuperAdmin)
        _QuickAction(icon: Icons.add_box_rounded, label: 'مورد', color: AppColors.primary, onTap: () => context.push('/operations/suppliers/create')),
      _QuickAction(icon: Icons.point_of_sale, label: 'بيع', color: AppColors.success, onTap: () => context.go('/pos')),
      _QuickAction(icon: Icons.download_rounded, label: 'وارد', color: Colors.blue, onTap: () => context.push('/operations/transaction/create?type=import')),
      _QuickAction(icon: Icons.upload_rounded, label: 'صادر', color: Colors.orange, onTap: () => context.push('/operations/transaction/create?type=export')),
      if (userRole != 'supplier')
        _QuickAction(icon: Icons.swap_horiz, label: 'نقل', color: Colors.purple, onTap: () => context.push('/operations/transaction/create?type=transfer')),
      if (userRole != 'supplier' && isSuperAdmin)
        _QuickAction(icon: Icons.people_alt, label: 'موردون', color: Colors.teal, onTap: () => context.go('/operations?tab=suppliers')),
      _QuickAction(icon: Icons.print_rounded, label: 'باركود', color: Colors.indigo, onTap: () => context.push('/barcode-print')),
      _QuickAction(icon: Icons.analytics_rounded, label: 'تقارير', color: Colors.brown, onTap: () => context.go('/reports')),
    ];
  }

  Widget _buildActivitiesList() {
    if (_loadingActivities) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: ShimmerList(itemCount: 4),
      );
    }
    if (_recentActivities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('لا توجد نشاطات بعد', style: GoogleFonts.manrope(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: _recentActivities.map((tx) {
        final type = tx['type'] as String? ?? 'sale';
        final amount = (tx['total_amount'] as num?)?.toDouble() ?? 0;
        final locationName = tx['location_name'] as String? ?? '';
        final performedBy = tx['performed_by'] as String? ?? '';
        final createdAt = tx['created_at'] as String? ?? '';
        final timeStr = _formatTime12h(createdAt);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AnimatedGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            borderRadius: 20,
            onTap: () {},
            child: _ActivityTile(
              title: '${_typeLabel(type)} ${amount > 0 ? '• ${amount.toStringAsFixed(0)} د' : ''}',
              subtitle: '$locationName ${performedBy.isNotEmpty ? '• $performedBy' : ''} ${timeStr.isNotEmpty ? '• $timeStr' : ''}',
              icon: _typeIcon(type),
              color: _typeColor(type),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final String suffix;
  final bool useGradientBorder;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color, this.suffix = '', this.useGradientBorder = false});

  @override
  Widget build(BuildContext context) {
    final cardContent = AnimatedGlassCard(
      padding: const EdgeInsets.all(12),
      onTap: () { HapticHelper.selectionClick(); },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              Icon(Icons.arrow_outward_rounded, color: Colors.grey.withOpacity(0.5), size: 16),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedCounter(
              value: value,
              suffix: suffix,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );

    if (useGradientBorder) {
      return GradientBorderCard(
        borderRadius: 20,
        borderWidth: 1.5,
        padding: EdgeInsets.zero,
        child: cardContent,
      );
    }
    return cardContent;
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
