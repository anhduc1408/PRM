class NotificationModel {
  final int id;
  final String type; // 'low_stock' | 'transfer' | 'order' | 'system'
  final String title;
  final String content;
  final int? targetUserId;
  final int? storeId;
  final int? productId;
  bool isRead;
  final DateTime createdAt;

  // For display
  final String? targetUserName;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.targetUserId,
    this.storeId,
    this.productId,
    this.isRead = false,
    required this.createdAt,
    this.targetUserName,
  });
}
