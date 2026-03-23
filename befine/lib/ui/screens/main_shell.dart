import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
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

  (List<NavigationDestination>, List<String>) _getTabs(String role, Map<String, dynamic> perms) {
    if (role == 'super_admin') {
      return (
        const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_rounded), label: 'المبيعات'),
          NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'المخزون'),
          NavigationDestination(icon: Icon(Icons.swap_horiz_rounded), label: 'العمليات'),
          NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'التقارير'),
        ],
        ['/dashboard', '/pos', '/inventory', '/operations', '/reports']
      );
    }
    
    // Admin / company owner
    if (role == 'admin' || role == 'owner') {
      return (
        const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.store_rounded), label: 'المتاجر'),
          NavigationDestination(icon: Icon(Icons.people_rounded), label: 'الموظفين'),
          NavigationDestination(icon: Icon(Icons.swap_horiz_rounded), label: 'العمليات'),
          NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'التقارير'),
        ],
        ['/dashboard', '/stores', '/settings/employees', '/operations', '/reports']
      );
    }

    // Employees (Cashier, Warehouse Worker, Supplier, etc.) using Custom Permissions
    final pos = perms['pos'] ?? (role == 'cashier' || role == 'supplier');
    final inv = perms['inventory'] ?? (role == 'warehouse_worker' || role == 'supplier');
    final ops = perms['operations'] ?? (role == 'supplier');
    final rep = perms['reports'] ?? false;

    final dests = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
    ];
    final routes = <String>['/dashboard'];

    if (pos == true) {
      dests.add(const NavigationDestination(icon: Icon(Icons.point_of_sale_rounded), label: 'المبيعات'));
      routes.add('/pos');
    }
    if (inv == true) {
      dests.add(const NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'المخزون'));
      routes.add('/inventory');
    }
    if (ops == true) {
      dests.add(const NavigationDestination(icon: Icon(Icons.swap_horiz_rounded), label: 'العمليات'));
      routes.add('/operations');
    }
    if (rep == true) {
      dests.add(const NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'التقارير'));
      routes.add('/reports');
    }

    return (dests, routes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final userState = ref.watch(authProvider);
    final role = userState.user?.role ?? 'cashier';

    // Fetch custom permissions
    final permsAsync = ref.watch(customPermissionsProvider);
    
    return permsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => _buildScaffold(context, location, role, {}, ref),
      data: (perms) => _buildScaffold(context, location, role, perms, ref),
    );
  }

  Widget _buildScaffold(BuildContext context, String location, String role, Map<String, dynamic> perms, WidgetRef ref) {
    final (destinations, routes) = _getTabs(role, perms);
    final currentIndex = _calcIndex(location, routes).clamp(0, destinations.length > 0 ? destinations.length - 1 : 0);

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
