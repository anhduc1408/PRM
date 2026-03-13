class InventoryLogModel {
  final int id;
  final int? sourceId; // warehouse_id
  final int productId;
  final String changeType; // 'sale', 'transfer_in', 'transfer_out', 'adjustment'
  final int quantityBefore;
  final int quantityChange;
  final int quantityAfter;
  final String referenceType; // 'sales_order' | 'stock_transfer' | 'manual'
  final int? referenceId;
  final int? orderId;
  final int? createdBy;
  final DateTime createdAt;

  // For display
  final String? productName;
  final String? createdByName;

  const InventoryLogModel({
    required this.id,
    this.sourceId,
    required this.productId,
    required this.changeType,
    required this.quantityBefore,
    required this.quantityChange,
    required this.quantityAfter,
    required this.referenceType,
    this.referenceId,
    this.orderId,
    this.createdBy,
    required this.createdAt,
    this.productName,
    this.createdByName,
  });
}
