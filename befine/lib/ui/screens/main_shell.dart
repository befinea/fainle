import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _calcIndex(String location) {
    if (location.startsWith('/inventory')) return 1;
    if (location.startsWith('/pos')) return 2;
    if (location.startsWith('/operations')) return 3;
    if (location.startsWith('/reports')) return 4;
    return 0; // dashboard
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _calcIndex(location);

    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        heroTag: 'barcode_fab',
        onPressed: () => context.push('/scanner'),
        backgroundColor: AppColors.primary,
        elevation: 4,
        mini: true,
        child: const Icon(Icons.qr_code_scanner_rounded, size: 22, color: Colors.white),
      ),
// main_shell.dart
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      extendBody: false, // Safely layout content above the navigation bar
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
            const routes = ['/dashboard', '/inventory', '/pos', '/operations', '/reports'];
            context.go(routes[index]);
          },
          height: 70,
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: AppColors.primary.withOpacity(0.15),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.warehouse_rounded), label: 'المخزون'),
            NavigationDestination(icon: Icon(Icons.point_of_sale_rounded), label: 'الكاشير'),
            NavigationDestination(icon: Icon(Icons.swap_horiz_rounded), label: 'العمليات'),
            NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'التقارير'),
          ],
        ),
      ),
    );
  }
}
