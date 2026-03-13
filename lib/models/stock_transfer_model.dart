class StockTransferItemModel {
  final int id;
  final int transferId;
  final int productId;
  final int estimateQuantity;
  int actualQuantity;

  // For display
  final String? productName;
  final String? productSku;

  StockTransferItemModel({
    required this.id,
    required this.transferId,
    required this.productId,
    required this.estimateQuantity,
    this.actualQuantity = 0,
    this.productName,
    this.productSku,
  });
}

class StockTransferModel {
  final int id;
  final int fromWarehouseId;
  final int toWarehouseId;
  final int requestedBy;
  final int? approvedBy;
  final String status; // 'pending' | 'approved' | 'in_transit' | 'received' | 'cancelled'
  final String? note;
  final DateTime createdAt;
  final DateTime? receivedAt;

  // For display
  final String? fromWarehouseName;
  final String? toWarehouseName;
  final String? requestedByName;
  final String? approvedByName;
  List<StockTransferItemModel> items;

  StockTransferModel({
    required this.id,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.requestedBy,
    this.approvedBy,
    required this.status,
    this.note,
    required this.createdAt,
    this.receivedAt,
    this.fromWarehouseName,
    this.toWarehouseName,
    this.requestedByName,
    this.approvedByName,
    this.items = const [],
  });
}
