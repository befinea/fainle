import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/inventory/warehouse_detail_screen.dart';
import '../../features/inventory/store_detail_screen.dart';
import '../../features/pos/pos_screen.dart';
import '../../features/operations/operations_screen.dart';
import '../../features/operations/transaction_create_screen.dart';
import '../../features/operations/supplier_create_edit_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/categories_screen.dart';
import '../../features/barcode/scanner_screen.dart';
import '../../features/barcode/barcode_print_screen.dart';
import '../../ui/screens/main_shell.dart';
import '../responsive/responsive_layout.dart';
import '../../ui/screens/web_shell.dart'; // Added import for WebShell

import '../../features/dashboard/web/web_dashboard_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/auth',

    // Auth-aware redirect
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthPage = state.uri.toString() == '/auth';

      if (isLoggedIn && isAuthPage) {
        // Already logged in → go to dashboard
        return '/dashboard';
      }
      if (!isLoggedIn && !isAuthPage) {
        // Not logged in → go to auth
        return '/auth';
      }
      return null; // No redirect needed
    },

    routes: [
      // Auth (Login / Register)
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),

      // Main App Shell with Responsive Navigation
      ShellRoute(
        builder: (context, state, child) => ResponsiveLayout(
          mobileShell: MainShell(child: child),
          webShell: WebShell(child: child),
        ),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const ResponsiveLayout(
              mobileShell: DashboardScreen(),
              webShell: WebDashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
            routes: [
              GoRoute(
                path: 'warehouse/:id',
                builder: (context, state) => WarehouseDetailScreen(
                  warehouseId: state.pathParameters['id']!,
                  warehouseName: state.extra as String? ?? 'مخزن غير معروف',
                ),
              ),
              GoRoute(
                path: 'store/:id',
                builder: (context, state) => StoreDetailScreen(
                  storeId: state.pathParameters['id']!,
                  storeName: state.extra as String? ?? 'متجر غير معروف',
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/pos',
            builder: (context, state) => const PosScreen(),
          ),
          GoRoute(
            path: '/operations',
            builder: (context, state) {
              final tab = state.uri.queryParameters['tab'];
              return OperationsScreen(initialTab: tab);
            },
            routes: [
              GoRoute(
                path: 'transaction/create',
                builder: (context, state) {
                  final type = state.uri.queryParameters['type'] ?? 'import';
                  return TransactionCreateScreen(type: type);
                },
              ),
              GoRoute(
                path: 'suppliers/create',
                builder: (context, state) => const SupplierCreateEditScreen(),
              ),
              GoRoute(
                path: 'suppliers/:id/edit',
                builder: (context, state) => SupplierCreateEditScreen(
                  supplierId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: 'categories',
                builder: (context, state) => const CategoriesScreen(),
              ),
            ],
          ),
        ],
      ),

      // Full-screen scanner (pushed on top of shell)
      GoRoute(
        path: '/scanner',
        builder: (context, state) => const ScannerScreen(),
      ),

      // Barcode Printing
      GoRoute(
        path: '/barcode-print',
        builder: (context, state) => const BarcodePrintScreen(),
      ),
    ],

    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('الصفحة غير موجودة: ${state.uri}')),
    ),
  );
}
