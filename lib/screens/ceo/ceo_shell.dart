import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';

class CeoShell extends StatelessWidget {
  final Widget child;
  const CeoShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final routeName = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('🧋', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            const Text('Mixue — CEO Admin',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              context.read<AuthProvider>().logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF1A1A2E),
            selectedIndex: _selectedIndex(routeName),
            onDestinationSelected: (i) {
              switch (i) {
                case 0:
                  context.go('/ceo/dashboard');
                  break;
                case 1:
                  context.go('/ceo/stores');
                  break;
              }
            },
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: AppColors.primary),
            selectedLabelTextStyle: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w600),
            unselectedIconTheme: const IconThemeData(color: Colors.white60),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white60),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store),
                label: Text('Cửa hàng'),
              ),
            ],
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(String route) {
    if (route.startsWith('/ceo/store')) return 1;
    return 0;
  }
}
