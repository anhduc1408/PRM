import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../constants/enums.dart';

// Auth
import '../../screens/auth/login_screen.dart';

// CEO
import '../../screens/ceo/ceo_dashboard_screen.dart';
import '../../screens/ceo/store_management_screen.dart';
import '../../screens/ceo/store_detail_screen.dart';

// IT
import '../../screens/it/role_management_screen.dart';

// Staff
import '../../screens/staff/staff_shell.dart';
import '../../screens/staff/product_list_screen.dart';
import '../../screens/staff/order_entry_screen.dart';
import '../../screens/staff/revenue_screen.dart';
import '../../screens/staff/shift_summary_screen.dart';
import '../../screens/staff/sales_history_screen.dart';
import '../../screens/staff/work_schedule_screen.dart';

// Manager
import '../../screens/manager/manager_shell.dart';
import '../../screens/manager/manager_staff_screen.dart';
import '../../screens/manager/manager_revenue_screen.dart';
import '../../screens/manager/manager_inventory_screen.dart';
import '../../screens/manager/manager_orders_screen.dart';

// Warehouse
import '../../screens/warehouse/warehouse_shell.dart';
import '../../screens/warehouse/warehouse_store_list_screen.dart';
import '../../screens/warehouse/warehouse_product_screen.dart';
import '../../screens/warehouse/warehouse_transfer_screen.dart';

// CEO Shell
import '../../screens/ceo/ceo_shell.dart';
// IT Shell
import '../../screens/it/it_shell.dart';

class AppRouter {
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: authProvider,
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final isLoginPage = state.matchedLocation == '/login';

        if (!isLoggedIn && !isLoginPage) return '/login';
        if (isLoggedIn && isLoginPage) {
          final role = authProvider.currentUser!.role;
          switch (role) {
            case UserRole.ceoAdmin:
              return '/ceo/dashboard';
            case UserRole.itAdmin:
              return '/it/roles';
            case UserRole.inventoryChecker:
              return '/warehouse/products';
            case UserRole.storeManager:
              return '/manager/staff';
            case UserRole.staff:
              return '/staff/products';
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),

        // ── CEO Routes ────────────────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => CeoShell(child: child),
          routes: [
            GoRoute(
              path: '/ceo/dashboard',
              builder: (context, state) => const CeoDashboardScreen(),
            ),
            GoRoute(
              path: '/ceo/stores',
              builder: (context, state) => const StoreManagementScreen(),
            ),
            GoRoute(
              path: '/ceo/stores/:storeId',
              builder: (context, state) => StoreDetailScreen(
                storeId: state.pathParameters['storeId']!,
              ),
            ),
          ],
        ),

        // ── IT Routes ─────────────────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => ItShell(child: child),
          routes: [
            GoRoute(
              path: '/it/roles',
              builder: (context, state) => const RoleManagementScreen(),
            ),
          ],
        ),

        // ── Staff Routes ───────────────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => StaffShell(child: child),
          routes: [
            GoRoute(
              path: '/staff/products',
              builder: (context, state) => const ProductListScreen(),
            ),
            GoRoute(
              path: '/staff/orders',
              builder: (context, state) => const OrderEntryScreen(),
            ),
            GoRoute(
              path: '/staff/revenue',
              builder: (context, state) => const StaffRevenueScreen(),
            ),
            GoRoute(
              path: '/staff/shift',
              builder: (context, state) => const ShiftSummaryScreen(),
            ),
            GoRoute(
              path: '/staff/history',
              builder: (context, state) => const SalesHistoryScreen(),
            ),
            GoRoute(
              path: '/staff/schedule',
              builder: (context, state) => const WorkScheduleScreen(),
            ),
          ],
        ),

        // ── Manager Routes ─────────────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => ManagerShell(child: child),
          routes: [
            GoRoute(
              path: '/manager/staff',
              builder: (context, state) => const ManagerStaffScreen(),
            ),
            GoRoute(
              path: '/manager/revenue',
              builder: (context, state) => const ManagerRevenueScreen(),
            ),
            GoRoute(
              path: '/manager/inventory',
              builder: (context, state) => const ManagerInventoryScreen(),
            ),
            GoRoute(
              path: '/manager/orders',
              builder: (context, state) => const ManagerOrdersScreen(),
            ),
          ],
        ),

        // ── Warehouse Routes ───────────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => WarehouseShell(child: child),
          routes: [
            GoRoute(
              path: '/warehouse/stores',
              builder: (context, state) => const WarehouseStoreListScreen(),
            ),
            GoRoute(
              path: '/warehouse/products',
              builder: (context, state) => WarehouseProductScreen(
                storeIdParam: state.uri.queryParameters['storeId'],
              ),
            ),
            GoRoute(
              path: '/warehouse/transfer',
              builder: (context, state) => const WarehouseTransferScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
