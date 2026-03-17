import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class WebShell extends ConsumerWidget {
  final Widget child;

  const WebShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: 250,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Row(
              children: [
                Icon(Icons.spa, color: AppColors.primary, size: 32),
                const SizedBox(width: 12),
                Text('Befine', style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary
                )),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'لوحة التحكم',
                  route: '/dashboard',
                ),
                _NavItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'المخزون',
                  route: '/inventory',
                ),
                _NavItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'نقطة البيع',
                  route: '/pos',
                ),
                _NavItem(
                  icon: Icons.sync_alt_rounded,
                  label: 'العمليات',
                  route: '/operations',
                ),
                _NavItem(
                  icon: Icons.analytics_rounded,
                  label: 'التقارير',
                  route: '/reports',
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'الإعدادات',
                  route: '/settings',
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/scanner'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('ماسح الباركود'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = GoRouterState.of(context).uri.toString().startsWith(route);
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: () => context.go(route),
    );
  }
}
