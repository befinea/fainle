import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_helper.dart';
import '../../features/auth/application/auth_service.dart';
import '../../features/auth/application/permissions_provider.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _calcIndex(String location, List<String> availableRoutes) {
    for (int i = 0; i < availableRoutes.length; i++) {
      if (location.startsWith(availableRoutes[i])) return i;
    }
    return 0;
  }

  (List<_NavItem>, List<String>) _getTabs(String role, Map<String, dynamic> perms) {
    if (role == 'super_admin') {
      return (
        const [
          _NavItem(icon: Icons.dashboard_rounded, label: 'الرئيسية'),
          _NavItem(icon: Icons.point_of_sale_rounded, label: 'المبيعات'),
          _NavItem(icon: Icons.inventory_2_rounded, label: 'المخزون'),
          _NavItem(icon: Icons.swap_horiz_rounded, label: 'العمليات'),
          _NavItem(icon: Icons.analytics_rounded, label: 'التقارير'),
        ],
        ['/dashboard', '/pos', '/inventory', '/operations', '/reports']
      );
    }

    if (role == 'admin' || role == 'owner') {
      return (
        const [
          _NavItem(icon: Icons.dashboard_rounded, label: 'الرئيسية'),
          _NavItem(icon: Icons.store_rounded, label: 'المتاجر'),
          _NavItem(icon: Icons.people_rounded, label: 'الموظفين'),
          _NavItem(icon: Icons.swap_horiz_rounded, label: 'العمليات'),
          _NavItem(icon: Icons.analytics_rounded, label: 'التقارير'),
        ],
        ['/dashboard', '/stores', '/settings/employees', '/operations', '/reports']
      );
    }

    final dash = perms['dashboard'] ?? true;
    final pos = perms['pos'] ?? (role == 'cashier' || role == 'supplier');
    final inv = perms['inventory'] ?? (role == 'warehouse_worker' || role == 'supplier');
    final stores = perms['stores'] ?? false;
    final ops = perms['operations'] ?? (role == 'supplier');
    final rep = perms['reports'] ?? false;
    final settings = perms['settings'] ?? false;

    final items = <_NavItem>[];
    final routes = <String>[];

    if (dash == true) {
      items.add(const _NavItem(icon: Icons.dashboard_rounded, label: 'الرئيسية'));
      routes.add('/dashboard');
    }
    if (pos == true) {
      items.add(const _NavItem(icon: Icons.point_of_sale_rounded, label: 'المبيعات'));
      routes.add('/pos');
    }
    if (inv == true) {
      items.add(const _NavItem(icon: Icons.inventory_2_rounded, label: 'المخزون'));
      routes.add('/inventory');
    }
    if (stores == true) {
      items.add(const _NavItem(icon: Icons.store_rounded, label: 'المتاجر'));
      routes.add('/stores');
    }
    if (ops == true) {
      items.add(const _NavItem(icon: Icons.swap_horiz_rounded, label: 'العمليات'));
      routes.add('/operations');
    }
    if (rep == true) {
      items.add(const _NavItem(icon: Icons.analytics_rounded, label: 'التقارير'));
      routes.add('/reports');
    }
    if (settings == true) {
      items.add(const _NavItem(icon: Icons.settings_rounded, label: 'الإعدادات'));
      routes.add('/settings');
    }

    // Fallback: ensure at least one tab
    if (items.isEmpty) {
      items.add(const _NavItem(icon: Icons.dashboard_rounded, label: 'الرئيسية'));
      routes.add('/dashboard');
    }

    return (items, routes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final userState = ref.watch(authProvider);
    final role = userState.user?.role ?? 'cashier';
    final permsAsync = ref.watch(customPermissionsProvider);

    return permsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => _buildScaffold(context, location, role, {}, ref),
      data: (perms) => _buildScaffold(context, location, role, perms, ref),
    );
  }

  Widget _buildScaffold(BuildContext context, String location, String role, Map<String, dynamic> perms, WidgetRef ref) {
    final (navItems, routes) = _getTabs(role, perms);
    final index = _calcIndex(location, routes);
    
    // Guard: Prevent access to disabled main tabs
    final allBottomNavPaths = ['/dashboard', '/pos', '/inventory', '/stores', '/operations', '/reports', '/settings'];
    final isBottomNavPath = allBottomNavPaths.any((p) => location.startsWith(p));
    bool isAllowed = routes.any((r) => location.startsWith(r));

    // Exception: Admins, Owners, and Super Admins have full access to settings
    if (location.startsWith('/settings') && (role == 'admin' || role == 'owner' || role == 'super_admin')) {
      isAllowed = true;
    }

    if (isBottomNavPath && !isAllowed && routes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(routes.first);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentIndex = index.clamp(0, navItems.isNotEmpty ? navItems.length - 1 : 0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        return Scaffold(
          extendBody: true,
          body: Row(
            children: [
              if (isDesktop)
                _DesktopSidebar(
                  items: navItems,
                  currentIndex: currentIndex,
                  isDark: isDark,
                  onTap: (index) {
                    HapticHelper.lightTap();
                    if (index < routes.length) context.go(routes[index]);
                  },
                ),
              Expanded(
                child: child,
              ),
            ],
          ),
          floatingActionButton: isDesktop ? null : _buildFabs(context, role, perms),
          // Float slightly above bottom nav
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: isDesktop ? null : Padding(
            padding: EdgeInsets.zero,
            child: _MobileBottomNav(
            items: navItems,
            currentIndex: currentIndex,
            isDark: isDark,
            onTap: (index) {
              HapticHelper.lightTap();
              if (index < routes.length) context.go(routes[index]);
            },
          ),
          ),
        );
      },
    );
  }

  Widget? _buildFabs(BuildContext context, String role, Map<String, dynamic> perms) {
    bool hasAi = false;
    bool hasBarcode = false;

    if (role == 'super_admin' || role == 'admin' || role == 'owner') {
      hasAi = true;
      hasBarcode = true;
    } else {
      hasAi = perms['ai_assistant'] ?? false;
      hasBarcode = perms['barcode'] ?? (role == 'cashier' || role == 'warehouse_worker');
    }

    if (!hasAi && !hasBarcode) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasAi) ...[
          FloatingActionButton(
            heroTag: 'ai_fab',
            onPressed: () {
              HapticHelper.mediumTap();
              context.push('/ai-assistant');
            },
            backgroundColor: AppColors.tertiary,
            elevation: 0,
            mini: true,
            child: const Icon(Icons.auto_awesome_rounded, size: 22, color: Colors.white),
          ),
          if (hasBarcode) const SizedBox(height: 8),
        ],
        if (hasBarcode)
          FloatingActionButton(
            heroTag: 'barcode_fab',
            onPressed: () {
              HapticHelper.mediumTap();
              context.push('/scanner');
            },
            backgroundColor: AppColors.primary,
            elevation: 0,
            mini: true,
            child: const Icon(Icons.qr_code_scanner_rounded, size: 22, color: Colors.white),
          ),
      ],
    );
  }
}

// ─── Desktop Sidebar (Exact Stitch Design) ───
class _DesktopSidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onTap;

  const _DesktopSidebar({
    required this.items,
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256, // w-64
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff0f172a).withOpacity(0.4) : Colors.white.withOpacity(0.6), // slate-900/40
        border: Border(
          left: BorderSide(color: Colors.white.withOpacity(0.1), width: 1), // border-l border-white/10
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1), // shadow-[0_20px_40px_rgba(0,0,0,0.4)]
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), // backdrop-blur-xl
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40), // px-6 py-8 mb-10
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نقطة البيع',
                      style: GoogleFonts.manrope(
                        fontSize: 24, // text-2xl
                        fontWeight: FontWeight.w900, // font-black
                        color: Colors.blue.shade400, // text-blue-400
                        letterSpacing: -0.5, // tracking-tight
                      ),
                    ),
                    const SizedBox(height: 4), // mt-1
                    Text(
                      'نظام الليدجر المضيء',
                      style: GoogleFonts.manrope(
                        fontSize: 12, // text-xs
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, // text-on-surface-variant
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final isActive = index == currentIndex;
                    final item = items[index];

                    if (isActive) {
                      return GestureDetector(
                        onTap: () => onTap(index),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8), // space-y-2
                          decoration: BoxDecoration(
                            color: Colors.blue.shade500.withOpacity(0.1), // bg-blue-500/10
                            border: Border(
                              right: BorderSide(color: Colors.blue.shade400, width: 4), // border-r-4 border-blue-400
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade500.withOpacity(0.3), // shadow-[0_0_15px_rgba(59,130,246,0.3)]
                                blurRadius: 15,
                              ),
                            ],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // px-4 py-3
                          child: Row(
                            children: [
                              Icon(item.icon, size: 20, color: Colors.blue.shade400),
                              const SizedBox(width: 16), // gap-4
                              Text(
                                item.label,
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return InkWell(
                        onTap: () => onTap(index),
                        borderRadius: BorderRadius.circular(12), // rounded-xl
                        hoverColor: Colors.white.withOpacity(0.05), // hover:bg-white/5
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // px-4 py-3
                          child: Row(
                            children: [
                              Icon(item.icon, size: 20, color: const Color(0xFF94A3B8)), // text-slate-400
                              const SizedBox(width: 16), // gap-4
                              Text(
                                item.label,
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF94A3B8), // text-slate-400
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mobile Floating Bottom Nav (Premium Animated) ───
class _MobileBottomNav extends StatefulWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onTap;

  const _MobileBottomNav({
    required this.items,
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MobileBottomNav> createState() => _MobileBottomNavState();
}

class _MobileBottomNavState extends State<_MobileBottomNav> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _initControllers();
    // Start active icon animation immediately
    if (widget.currentIndex < _controllers.length) {
      _controllers[widget.currentIndex].forward();
    }
  }

  void _initControllers() {
    _controllers = List.generate(widget.items.length, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
    });

    _scaleAnimations = _controllers.map((c) {
      return Tween<double>(begin: 1.0, end: 1.05).animate( // Subtle scale
        CurvedAnimation(parent: c, curve: Curves.easeOutCubic),
      );
    }).toList();

    _slideAnimations = _controllers.map((c) {
      return Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.22)).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOutBack),
      );
    }).toList();
  }

  @override
  void didUpdateWidget(covariant _MobileBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle item count changes
    if (oldWidget.items.length != widget.items.length) {
      for (final c in _controllers) {
        c.dispose();
      }
      _initControllers();
      if (widget.currentIndex < _controllers.length) {
        _controllers[widget.currentIndex].forward();
      }
      return;
    }

    // Animate transition between tabs
    if (oldWidget.currentIndex != widget.currentIndex) {
      if (oldWidget.currentIndex < _controllers.length) {
        _controllers[oldWidget.currentIndex].reverse();
      }
      if (widget.currentIndex < _controllers.length) {
        _controllers[widget.currentIndex].forward();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xff020617).withOpacity(0.7) : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(widget.isDark ? 0.3 : 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 14.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(widget.items.length, (index) {
                  final isActive = index == widget.currentIndex;
                  final icon = widget.items[index].icon;
                  final label = widget.items[index].label;

                  return GestureDetector(
                    onTap: () => widget.onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: SlideTransition(
                      position: _slideAnimations[index],
                      child: ScaleTransition(
                        scale: _scaleAnimations[index],
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: isActive ? 14 : 10,
                            vertical: isActive ? 6 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                color: isActive
                                    ? Colors.white
                                    : (widget.isDark ? Colors.white54 : const Color(0xFF64748B)),
                                size: isActive ? 24 : 26,
                              ),
                              // Animated label for active icon
                              AnimatedCrossFade(
                                firstChild: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                secondChild: const SizedBox.shrink(),
                                crossFadeState: isActive
                                    ? CrossFadeState.showFirst
                                    : CrossFadeState.showSecond,
                                duration: const Duration(milliseconds: 250),
                                sizeCurve: Curves.easeOutCubic,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nav Item Data ───
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

