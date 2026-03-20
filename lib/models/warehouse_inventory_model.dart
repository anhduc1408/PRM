class WarehouseInventoryModel {
  final int id;
  final int warehouseId;
  final int productId;
  int quantity;
  int minQuantity;
  DateTime? expiryDate;
  final DateTime updatedAt;

  // For display — joined
  final String? productName;
  final String? warehouseName;
  final String? productSku;

  WarehouseInventoryModel({
    required this.id,
    required this.warehouseId,
    required this.productId,
    required this.quantity,
    required this.minQuantity,
    this.expiryDate,
    required this.updatedAt,
    this.productName,
    this.warehouseName,
    this.productSku,
  });

  bool get isLowStock => quantity <= minQuantity;
}
