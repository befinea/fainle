import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/application/auth_service.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _calcIndex(String location, String role) {
    if (role == 'super_admin') {
      if (location.startsWith('/pos')) return 1;
      if (location.startsWith('/inventory')) return 2;
      if (location.startsWith('/operations')) return 3;
      if (location.startsWith('/reports')) return 4;
      return 0;
    }
    if (role == 'cashier') {
      if (location.startsWith('/pos')) return 1;
      return 0;
    }
    if (role == 'warehouse_worker') {
      if (location.startsWith('/inventory')) return 1;
      return 0;
    }
    if (role == 'supplier') {
      if (location.startsWith('/pos')) return 1;
      if (location.startsWith('/inventory')) return 2;
      if (location.startsWith('/operations')) return 3;
      return 0;
    }
    // Admin (company owner): Dashboard, Stores, Employees, Operations, Reports
    if (location.startsWith('/stores')) return 1;
    if (location.startsWith('/employees') || location.startsWith('/settings/employees')) return 2;
    if (location.startsWith('/operations')) return 3;
    if (location.startsWith('/reports')) return 4;
    return 0;
  }

  List<NavigationDestination> _getDestinations(String role) {
    if (role == 'super_admin') {
      return const [
        NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.point_of_sale_rounded), label: 'المبيعات'),
        NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'المخزون'),
        NavigationDestination(icon: Icon(Icons.swap_horiz_rounded), label: 'العمليات'),
        NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'التقارير'),
      ];
    }
    if (role == 'cashier') {
      return const [
        NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.point_of_sale_rounded), label: 'الكاشير'),
      ];
    }
    if (role == 'warehouse_worker') {
      return const [
        NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.warehouse_rounded), label: 'المخزون'),
      ];
    }
    if (role == 'supplier') {
      return const [
        NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.point_of_sale_rounded), label: 'المبيعات'),
        NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'المخزون'),
        NavigationDestination(icon: Icon(Icons.swap_horiz_rounded), label: 'العمليات'),
      ];
    }
    // Admin / company owner
    return const [
      NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
      NavigationDestination(icon: Icon(Icons.store_rounded), label: 'المتاجر'),
      NavigationDestination(icon: Icon(Icons.people_rounded), label: 'الموظفين'),
      NavigationDestination(icon: Icon(Icons.swap_horiz_rounded), label: 'العمليات'),
      NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'التقارير'),
    ];
  }

  List<String> _getRoutes(String role) {
    if (role == 'super_admin') {
      return ['/dashboard', '/pos', '/inventory', '/operations', '/reports'];
    }
    if (role == 'cashier') {
      return ['/dashboard', '/pos'];
    }
    if (role == 'warehouse_worker') {
      return ['/dashboard', '/inventory'];
    }
    if (role == 'supplier') {
      return ['/dashboard', '/pos', '/inventory', '/operations'];
    }
    // Admin / company owner
    return ['/dashboard', '/stores', '/settings/employees', '/operations', '/reports'];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final userState = ref.watch(authProvider);
    final role = userState.user?.role ?? 'cashier';

    final destinations = _getDestinations(role);
    final routes = _getRoutes(role);
    final currentIndex = _calcIndex(location, role).clamp(0, destinations.length - 1);

    return Scaffold(
      body: child,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'ai_fab',
            onPressed: () => context.push('/ai-assistant'),
            backgroundColor: const Color(0xFF7C3AED),
            elevation: 6,
            mini: true,
            child: const Icon(Icons.auto_awesome_rounded, size: 22, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'barcode_fab',
            onPressed: () => context.push('/scanner'),
            backgroundColor: AppColors.primary,
            elevation: 4,
            mini: true,
            child: const Icon(Icons.qr_code_scanner_rounded, size: 22, color: Colors.white),
          ),
        ],
      ),
      extendBody: false,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            if (index < routes.length) {
              context.go(routes[index]);
            }
          },
          height: 70,
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: AppColors.primary.withOpacity(0.15),
          destinations: destinations,
        ),
      ),
    );
  }
}
