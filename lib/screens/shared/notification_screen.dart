import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/notification_provider.dart';
import '../../models/notification_model.dart';

/// Màn hình danh sách thông báo.
/// Phân biệt đã đọc / chưa đọc, có nút đánh dấu đã đọc.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // Tải thông báo khi mở màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid != null) {
      await context.read<NotificationProvider>().loadNotifications(uid);
    }
  }

  Future<void> _triggerCheck() async {
    final auth = context.read<AuthProvider>();
    final uid  = auth.currentUser?.id;
    final sid  = auth.currentUser?.storeId;
    final np   = context.read<NotificationProvider>();
    final created = await np.triggerLowStockCheck(storeId: sid, userId: uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created > 0 ? 'Tạo $created thông báo hàng sắp hết' : 'Không có sản phẩm nào sắp hết hàng',
        ),
        backgroundColor: created > 0 ? AppColors.warning : AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _markAll() async {
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null) return;
    await context.read<NotificationProvider>().markAllAsRead(uid);
  }

  Future<void> _markOne(NotificationModel n) async {
    if (n.isRead) return;
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null) return;
    await context.read<NotificationProvider>().markAsRead(n.id, uid);
  }

  @override
  Widget build(BuildContext context) {
    final np       = context.watch<NotificationProvider>();
    final unread   = np.unreadCount;
    final list     = np.notifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Thông báo'),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Nút kích hoạt kiểm tra hàng sắp hết
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Kiểm tra hàng sắp hết',
            onPressed: _triggerCheck,
          ),
          // Nút đánh dấu tất cả đã đọc
          if (unread > 0)
            TextButton.icon(
              onPressed: _markAll,
              icon: const Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
              label: const Text('Đọc tất cả', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: np.isLoading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _NotificationTile(
                      notification: list[i],
                      onTap: () => _markOne(list[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text(
            'Không có thông báo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bấm 🔄 để kiểm tra hàng sắp hết hàng',
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _triggerCheck,
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Kiểm tra ngay'),
          ),
        ],
      ),
    );
  }
}

// ── Notification Tile ──────────────────────────────────────────────────────
class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n    = notification;
    final isLowStock = n.type == 'low_stock';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: n.isRead ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: n.isRead
            ? BorderSide.none
            : BorderSide(color: isLowStock ? AppColors.warning : AppColors.primary, width: 1.2),
      ),
      color: n.isRead ? AppColors.surface : (isLowStock ? AppColors.warningLight : AppColors.infoLight),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon theo type
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isLowStock
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isLowStock ? Icons.warning_amber_rounded : Icons.notifications_rounded,
                  color: isLowStock ? AppColors.warning : AppColors.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: n.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 11, color: AppColors.textHint),
                        const SizedBox(width: 3),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm', 'vi').format(n.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                        ),
                        const Spacer(),
                        if (!n.isRead)
                          GestureDetector(
                            onTap: onTap,
                            child: const Text(
                              'Đánh dấu đã đọc',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
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
      ),
    );
  }
}
