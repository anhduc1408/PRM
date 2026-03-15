import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/warehouse_provider.dart';
import '../../widgets/notification_bell.dart';

class WarehouseShell extends StatefulWidget {
  final Widget child;
  const WarehouseShell({super.key, required this.child});

  @override
  State<WarehouseShell> createState() => _WarehouseShellState();
}

class _WarehouseShellState extends State<WarehouseShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WarehouseProvider>().loadAll();
    });
  }

  int _currentIndex(BuildContext ctx) {
    final loc = GoRouterState.of(ctx).matchedLocation;
    final isChecker = context.read<AuthProvider>().currentUser?.role == UserRole.inventoryChecker;
    
    if (isChecker) {
      if (loc.startsWith('/warehouse/transfer')) return 1;
      return 0; // products
    } else {
      if (loc.startsWith('/warehouse/products')) return 1;
      if (loc.startsWith('/warehouse/transfer')) return 2;
      return 0; // stores
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final wh = context.watch<WarehouseProvider>();
    final lowCount = wh.lowStockItems.length;
    final idx = _currentIndex(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A4731), Color(0xFF2D7A50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text('🏭', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Quản lý kho',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              if (user != null)
                Text(user.fullName,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
            ],
          ),
        ]),
        actions: [
          if (lowCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                label: Text('⚠️ $lowCount sắp hết',
                    style: const TextStyle(fontSize: 11, color: Colors.white)),
                backgroundColor: AppColors.warning,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Đăng xuất',
            onPressed: () {
              context.read<AuthProvider>().logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          final isChecker = context.read<AuthProvider>().currentUser?.role == UserRole.inventoryChecker;
          if (isChecker) {
            if (i == 0) context.go('/warehouse/products');
            if (i == 1) context.go('/warehouse/transfer');
          } else {
            if (i == 0) context.go('/warehouse/stores');
            if (i == 1) context.go('/warehouse/products');
            if (i == 2) context.go('/warehouse/transfer');
          }
        },
        backgroundColor: AppColors.surface,
        indicatorColor: const Color(0xFF2D7A50).withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: user?.role == UserRole.inventoryChecker 
          ? const [
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: Color(0xFF2D7A50)),
              label: 'Hàng hóa & Tồn kho',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping, color: Color(0xFF2D7A50)),
              label: 'Phân phối',
            ),
          ] 
          : const [
            NavigationDestination(
              icon: Icon(Icons.store_outlined),
              selectedIcon: Icon(Icons.store, color: Color(0xFF2D7A50)),
              label: 'Cửa hàng',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: Color(0xFF2D7A50)),
              label: 'Hàng hóa',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping, color: Color(0xFF2D7A50)),
              label: 'Phân phối',
            ),
          ],
      ),
    );
  }
}
