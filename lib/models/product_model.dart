class ProductModel {
  final int id;
  final String sku;
  final String? barcode;
  final String name;
  final int categoryId;
  final String unit; // 'pcs', 'cup', 'box', etc.
  final double costPrice;
  final double sellingPrice;
  final String status; // 'active' | 'inactive'
  final DateTime createdAt;
  final DateTime updatedAt;

  // For display — joined from categories
  final String? categoryName;
  // Legacy / display helpers
  final String emoji;

  const ProductModel({
    required this.id,
    required this.sku,
    this.barcode,
    required this.name,
    required this.categoryId,
    this.unit = 'cup',
    required this.costPrice,
    required this.sellingPrice,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.emoji = '🧋',
  });

  double get price => sellingPrice;
}

class ProductSaleModel {
  final int productId;
  final String productName;
  final int quantity;
  final double totalRevenue;

  const ProductSaleModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.totalRevenue,
  });
}
