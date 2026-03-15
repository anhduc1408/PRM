import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/notification_provider.dart';

/// Icon chuông thông báo có badge số chưa đọc.
/// Dùng chung trong AppBar của tất cả các shell.
///
/// Khi mount: tự động load notifications + trigger kiểm tra low-stock.
/// Click → điều hướng đến /notifications.
class NotificationBell extends StatefulWidget {
  /// Màu icon (mặc định trắng để dùng trong AppBar màu tối)
  final Color iconColor;

  const NotificationBell({super.key, this.iconColor = Colors.white});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final uid  = auth.currentUser?.id;
    if (uid == null) return;

    final np = context.read<NotificationProvider>();
    // Load danh sách thông báo
    await np.loadNotifications(uid);
    // Kích hoạt kiểm tra hàng sắp hết (anti-spam nên an toàn để gọi mỗi lần vào)
    await np.triggerLowStockCheck(
      storeId: auth.currentUser?.storeId,
      userId: uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationProvider>().unreadCount;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            unread > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
            color: widget.iconColor,
          ),
          tooltip: 'Thông báo',
          onPressed: () => context.push('/notifications'),
        ),
        if (unread > 0)
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE30613), // AppColors.primary
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
