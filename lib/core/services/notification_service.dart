/// NotificationService - Helper tạo notification chuẩn cho toàn bộ app.
/// Mọi thao tác thêm/sửa/xóa đều gọi qua đây để đảm bảo nhất quán.
library;

import '../../data/database_service.dart';

class NotificationService {
  NotificationService._();

  static final _db = DatabaseService.instance;

  // ─── Loại type ────────────────────────────────────────────────────────────
  static const typeSystem    = 'system';
  static const typeProduct   = 'product';
  static const typeInventory = 'inventory';
  static const typeTransfer  = 'transfer';
  static const typeStaff     = 'role_update';

  // ─── Gửi đến list userId ─────────────────────────────────────────────────
  static Future<void> _send({
    required String type,
    required String title,
    required String content,
    required List<int> targetUserIds,
    int? storeId,
    int? productId,
  }) async {
    for (final uid in targetUserIds) {
      await _db.insertNotification(
        type: type,
        title: title,
        content: content,
        targetUserId: uid,
        storeId: storeId,
        productId: productId,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PRODUCT NOTIFICATIONS
  // ──────────────────────────────────────────────────────────────────────────

  /// Thêm sản phẩm mới
  static Future<void> productAdded({
    required int actorId,
    required String productName,
    required String sku,
  }) async {
    await _send(
      type: typeProduct,
      title: 'Sản phẩm mới đã được thêm',
      content: '[$sku] $productName đã được thêm vào danh mục hàng hóa.',
      targetUserIds: [actorId],
    );
  }

  /// Sửa thông tin sản phẩm
  static Future<void> productUpdated({
    required int actorId,
    required String productName,
    required String sku,
    required int productId,
  }) async {
    await _send(
      type: typeProduct,
      title: 'Thông tin sản phẩm đã được cập nhật',
      content: '[$sku] $productName đã được cập nhật thông tin.',
      targetUserIds: [actorId],
      productId: productId,
    );
  }

  /// Xóa sản phẩm
  static Future<void> productDeleted({
    required int actorId,
    required String productName,
    required String sku,
  }) async {
    await _send(
      type: typeProduct,
      title: 'Sản phẩm đã bị xóa',
      content: '[$sku] $productName đã bị xóa khỏi hệ thống.',
      targetUserIds: [actorId],
    );
  }

  /// Bật / Tắt trạng thái sản phẩm
  static Future<void> productStatusChanged({
    required int actorId,
    required String productName,
    required String sku,
    required bool isActive,
    required int productId,
  }) async {
    final action = isActive ? 'được kích hoạt' : 'bị tạm ngưng';
    final emoji  = isActive ? '✅' : '⏸️';
    await _send(
      type: typeProduct,
      title: '$emoji Trạng thái sản phẩm thay đổi',
      content: '[$sku] $productName đã $action.',
      targetUserIds: [actorId],
      productId: productId,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // INVENTORY NOTIFICATIONS
  // ──────────────────────────────────────────────────────────────────────────

  /// Điều chỉnh số lượng tồn kho
  static Future<void> inventoryAdjusted({
    required int actorId,
    required String productName,
    required String warehouseName,
    required int oldQty,
    required int newQty,
    required int productId,
  }) async {
    final diff = newQty - oldQty;
    final sign = diff >= 0 ? '+$diff' : '$diff';
    await _send(
      type: typeInventory,
      title: 'Tồn kho đã được điều chỉnh',
      content: '$productName tại $warehouseName: $oldQty → $newQty ($sign đơn vị).',
      targetUserIds: [actorId],
      productId: productId,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TRANSFER NOTIFICATIONS
  // ──────────────────────────────────────────────────────────────────────────

  /// Tạo phiếu chuyển kho
  static Future<void> transferCreated({
    required int actorId,
    required String fromWarehouse,
    required String toWarehouse,
    required int itemCount,
    required int totalQty,
    List<int> notifyUserIds = const [],
  }) async {
    final ids = {actorId, ...notifyUserIds}.toList();
    await _send(
      type: typeTransfer,
      title: '🚚 Phiếu chuyển kho mới đã được tạo',
      content: 'Chuyển hàng từ $fromWarehouse → $toWarehouse. '
          '$itemCount mặt hàng, ~$totalQty đơn vị. Đang chờ xác nhận.',
      targetUserIds: ids,
    );
  }

  /// Xác nhận nhận hàng
  static Future<void> transferReceived({
    required int actorId,
    required String fromWarehouse,
    required String toWarehouse,
    required int itemCount,
    required int totalActual,
    List<int> notifyUserIds = const [],
  }) async {
    final ids = {actorId, ...notifyUserIds}.toList();
    await _send(
      type: typeTransfer,
      title: '📦 Đã xác nhận nhận hàng',
      content: 'Hàng từ $fromWarehouse → $toWarehouse đã được nhận. '
          '$itemCount mặt hàng, tổng $totalActual đơn vị. Tồn kho đã cập nhật.',
      targetUserIds: ids,
    );
  }
}
