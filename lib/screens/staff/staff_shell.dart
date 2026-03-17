import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../data/database_service.dart';

class StaffShell extends StatefulWidget {
  final Widget child;
  const StaffShell({super.key, required this.child});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _currentIndex = 0;
  String? _storeName;

  @override
  void initState() {
    super.initState();
    _fetchStoreName();
  }

  Future<void> _fetchStoreName() async {
    final auth = context.read<AuthProvider>();
    final storeId = auth.currentUser?.storeId;
    if (storeId != null) {
      final store = await DatabaseService.instance.getStore(storeId);
      if (mounted) {
        setState(() {
          _storeName = store?.name;
        });
      }
    }
  }

  final _tabs = [
    (path: '/staff/products', icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view, label: 'Sản phẩm'),
    (path: '/staff/orders', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Nhập đơn'),
    (path: '/staff/revenue', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Doanh thu'),
    (path: '/staff/shift', icon: Icons.attach_money_outlined, activeIcon: Icons.attach_money, label: 'Ca làm'),
    (path: '/staff/history', icon: Icons.history_outlined, activeIcon: Icons.history, label: 'Lịch sử'),
    (path: '/staff/schedule', icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Lịch làm'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => t.path == route);
    if (idx >= 0) _currentIndex = idx;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mixue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                Text(
                  _storeName ?? (auth.currentUser?.storeId != null ? 'Cửa hàng #${auth.currentUser!.storeId}' : 'Nhân viên'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
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
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() => _currentIndex = i);
            context.go(_tabs[i].path);
          },
          items: _tabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t.icon),
                    activeIcon: Icon(t.activeIcon),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
