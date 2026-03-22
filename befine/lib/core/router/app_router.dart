import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/inventory/warehouse_detail_screen.dart';
import '../../features/inventory/store_detail_screen.dart';
import '../../features/inventory/product_detail_screen.dart';
import '../../features/inventory/stores_list_screen.dart';
import '../../features/pos/pos_screen.dart';
import '../../features/operations/operations_screen.dart';
import '../../features/operations/transaction_create_screen.dart';
import '../../features/operations/supplier_create_edit_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/categories_screen.dart';
import '../../features/settings/company_management_screen.dart';
import '../../features/settings/employee_invites_screen.dart';
import '../../features/settings/audit_log_screen.dart';
import '../../features/settings/subscription_plans_screen.dart';
import '../../features/barcode/scanner_screen.dart';
import '../../features/ai_assistant/presentation/ai_assistant_screen.dart';
import '../../features/barcode/barcode_print_screen.dart';
import '../../ui/screens/main_shell.dart';
import '../../ui/screens/web_shell.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/auth',

    // Auth-aware redirect
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthPage = state.uri.toString() == '/auth';
      if (!isLoggedIn && !isAuthPage) {
        // Not logged in → go to auth
        return '/auth';
      }

      if (isLoggedIn && isAuthPage) {
        return '/dashboard';
      }

      return null; // No redirect needed
    },

    routes: [
      // Auth (Login / Register)
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),

      // Onboarding (First time company setup)
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Main App Shell with Responsive Navigation
      ShellRoute(
        builder: (context, state, child) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (screenWidth > 800) {
            return WebShell(child: child);
          } else {
            return MainShell(child: child);
          }
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
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
            path: '/stores',
            builder: (context, state) => const StoresListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => StoreDetailScreen(
                  storeId: state.pathParameters['id']!,
                  storeName: state.extra as String? ?? 'متجر',
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
              GoRoute(
                path: 'companies',
                builder: (context, state) => const CompanyManagementScreen(),
              ),
              GoRoute(
                path: 'employees',
                builder: (context, state) => const EmployeeInvitesScreen(),
              ),
              GoRoute(
                path: 'audit-log',
                builder: (context, state) => const AuditLogScreen(),
              ),
              GoRoute(
                path: 'plans',
                builder: (context, state) => const SubscriptionPlansScreen(),
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

      // AI Assistant (full screen)
      GoRoute(
        path: '/ai-assistant',
        builder: (context, state) => const AiAssistantScreen(),
      ),

      // Product Detail (full screen)
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ProductDetailScreen(
            productId: state.pathParameters['id']!,
            storeId: extra?['storeId'] as String?,
          );
        },
      ),
    ],

    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('الصفحة غير موجودة: ${state.uri}')),
    ),
  );
}
