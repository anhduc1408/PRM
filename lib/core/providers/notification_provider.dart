import 'package:flutter/material.dart';
import '../../data/database_service.dart';
import '../../models/notification_model.dart';

/// Quản lý state danh sách thông báo và badge số chưa đọc.
/// Phải được load lại sau khi user đăng nhập (gọi [loadNotifications]).
class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<NotificationModel> get notifications  => _notifications;
  int                     get unreadCount    => _unreadCount;
  bool                    get isLoading      => _isLoading;

  // ── Load notifications của user hiện tại ──────────────────────────────────
  Future<void> loadNotifications(int userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _notifications = await DatabaseService.instance.getNotifications(userId: userId);
      _unreadCount   = await DatabaseService.instance.getUnreadNotificationCount(userId);
    } catch (_) {
      _notifications = [];
      _unreadCount   = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Đánh dấu 1 notification đã đọc ───────────────────────────────────────
  Future<void> markAsRead(int notificationId, int userId) async {
    await DatabaseService.instance.markNotificationRead(notificationId);
    // Cập nhật local state không cần query lại
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx >= 0 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
      _unreadCount = (_unreadCount - 1).clamp(0, 9999);
      notifyListeners();
    }
  }

  // ── Đánh dấu tất cả đã đọc ───────────────────────────────────────────────
  Future<void> markAllAsRead(int userId) async {
    await DatabaseService.instance.markAllNotificationsRead(userId);
    for (final n in _notifications) {
      n.isRead = true;
    }
    _unreadCount = 0;
    notifyListeners();
  }

  // ── Kích hoạt kiểm tra hàng sắp hết và tạo notifications ─────────────────
  /// [storeId]: giới hạn theo cửa hàng (null = tất cả).
  /// [userId]: sau khi tạo xong, reload notifications cho user này.
  Future<int> triggerLowStockCheck({int? storeId, int? userId}) async {
    final created = await DatabaseService.instance
        .checkAndInsertLowStockNotifications(storeId: storeId);
    if (userId != null && created > 0) {
      await loadNotifications(userId);
    }
    return created;
  }

  // ── Xóa state khi logout ─────────────────────────────────────────────────
  void clear() {
    _notifications = [];
    _unreadCount   = 0;
    notifyListeners();
  }
}
