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

    final pos = perms['pos'] ?? (role == 'cashier' || role == 'supplier');
    final inv = perms['inventory'] ?? (role == 'warehouse_worker' || role == 'supplier');
    final ops = perms['operations'] ?? (role == 'supplier');
    final rep = perms['reports'] ?? false;

    final items = <_NavItem>[const _NavItem(icon: Icons.dashboard_rounded, label: 'الرئيسية')];
    final routes = <String>['/dashboard'];

    if (pos == true) {
      items.add(const _NavItem(icon: Icons.point_of_sale_rounded, label: 'المبيعات'));
      routes.add('/pos');
    }
    if (inv == true) {
      items.add(const _NavItem(icon: Icons.inventory_2_rounded, label: 'المخزون'));
      routes.add('/inventory');
    }
    if (ops == true) {
      items.add(const _NavItem(icon: Icons.swap_horiz_rounded, label: 'العمليات'));
      routes.add('/operations');
    }
    if (rep == true) {
      items.add(const _NavItem(icon: Icons.analytics_rounded, label: 'التقارير'));
      routes.add('/reports');
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
    final currentIndex = _calcIndex(location, routes).clamp(0, navItems.isNotEmpty ? navItems.length - 1 : 0);
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
          floatingActionButton: isDesktop ? null : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 8),
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
          ),
          // Float slightly above bottom nav
          floatingActionButtonLocation: FloatingActionButtonLocation.endContained,
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

// ─── Mobile Floating Bottom Nav (Exact Stitch Design) ───
class _MobileBottomNav extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), // Float above screen
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff020617).withOpacity(0.7) : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(40), // Bubble shape
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(isDark ? 0.3 : 0.1),
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
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  final isActive = index == currentIndex;
                  final icon = items[index].icon;
                  if (isActive) {
                    return GestureDetector(
                      onTap: () => onTap(index),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack, // Gives a nice bounce
                        tween: Tween(begin: 0.0, end: -10.0), // Protrude upwards
                        builder: (context, val, child) {
                          return Transform.translate(
                            offset: Offset(0, val),
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary, // Solid color for the popped bubble
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                      ),
                    );
                  } else {
                    return GestureDetector(
                      onTap: () => onTap(index),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.transparent,
                        child: Icon(icon, color: isDark ? Colors.white54 : const Color(0xFF64748B), size: 26),
                      ),
                    );
                  }
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

