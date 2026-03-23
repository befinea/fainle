import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../features/auth/application/auth_service.dart';
import '../../features/auth/application/permissions_provider.dart';

class WebShell extends ConsumerWidget {
  final Widget child;

  const WebShell({super.key, required this.child});

  List<_SidebarItem> _getItems(String role, Map<String, dynamic> perms) {
    if (role == 'super_admin') {
      return [
        _SidebarItem(Icons.dashboard_rounded, 'لوحة التحكم', '/dashboard'),
        _SidebarItem(Icons.point_of_sale_rounded, 'المبيعات', '/pos'),
        _SidebarItem(Icons.inventory_2_rounded, 'المخزون', '/inventory'),
        _SidebarItem(Icons.swap_horiz_rounded, 'العمليات', '/operations'),
        _SidebarItem(Icons.analytics_rounded, 'التقارير', '/reports'),
        _SidebarItem(Icons.settings_rounded, 'الإعدادات', '/settings'),
      ];
    }
    
    // Admin / company owner
    if (role == 'admin' || role == 'owner') {
      return [
        _SidebarItem(Icons.dashboard_rounded, 'لوحة التحكم', '/dashboard'),
        _SidebarItem(Icons.store_rounded, 'المتاجر', '/stores'),
        _SidebarItem(Icons.people_rounded, 'الموظفين', '/settings/employees'),
        _SidebarItem(Icons.swap_horiz_rounded, 'العمليات', '/operations'),
        _SidebarItem(Icons.analytics_rounded, 'التقارير', '/reports'),
        _SidebarItem(Icons.settings_rounded, 'الإعدادات', '/settings'),
      ];
    }

    // Employees (Cashier, Warehouse Worker, Supplier, etc.) using Custom Permissions
    final pos = perms['pos'] ?? (role == 'cashier' || role == 'supplier');
    final inv = perms['inventory'] ?? (role == 'warehouse_worker' || role == 'supplier');
    final ops = perms['operations'] ?? (role == 'supplier');
    final rep = perms['reports'] ?? false;

    final items = [_SidebarItem(Icons.dashboard_rounded, 'لوحة التحكم', '/dashboard')];

    if (pos == true) items.add(_SidebarItem(Icons.point_of_sale_rounded, 'المبيعات', '/pos'));
    if (inv == true) items.add(_SidebarItem(Icons.inventory_2_rounded, 'المخزون', '/inventory'));
    if (ops == true) items.add(_SidebarItem(Icons.swap_horiz_rounded, 'العمليات', '/operations'));
    if (rep == true) items.add(_SidebarItem(Icons.analytics_rounded, 'التقارير', '/reports'));

    // Employees might have access to some settings, but usually they don't have a settings pane.
    // So we don't add settings by default unless they have a specific permission.
    return items;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userState = ref.watch(authProvider);
    final role = userState.user?.role ?? 'cashier';
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    
    // Fetch custom permissions
    final permsAsync = ref.watch(customPermissionsProvider);
    
    return permsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => _buildScaffold(context, theme, role, {}, isDark, ref),
      data: (perms) => _buildScaffold(context, theme, role, perms, isDark, ref),
    );
  }

  Widget _buildScaffold(BuildContext context, ThemeData theme, String role, Map<String, dynamic> perms, bool isDark, WidgetRef ref) {
    final items = _getItems(role, perms);
    final userState = ref.watch(authProvider);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                right: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
            ),
            child: Column(
              children: [
                // Logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.spa, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text('Befine', style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      )),
                    ],
                  ),
                ),

                // Nav items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: items.map((item) {
                      final location = GoRouterState.of(context).uri.toString();
                      final isSelected = location.startsWith(item.route) &&
                          (item.route == '/settings' ? location == '/settings' || !items.any((i) => i.route != '/settings' && location.startsWith(i.route)) : true);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          leading: Icon(
                            item.icon,
                            color: isSelected ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                            size: 22,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : theme.colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          selected: isSelected,
                          selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          dense: true,
                          onTap: () => context.go(item.route),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Bottom section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Scanner button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/scanner'),
                          icon: const Icon(Icons.qr_code_scanner, size: 18),
                          label: const Text('ماسح الباركود'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // AI Assistant button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/ai-assistant'),
                          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: const Text('المساعد الذكي'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Theme toggle + User
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              userState.user?.name ?? 'مستخدم',
                              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final String route;

  _SidebarItem(this.icon, this.label, this.route);
}
