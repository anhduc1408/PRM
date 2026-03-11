import 'package:mixue_manager/core/constants/enums.dart';

class ProductModel {
  final String id;
  final String name;
  final double price;
  final ProductCategory category;
  final String emoji;
  final String description;
  final String storeId;
  final bool isAvailable;

  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.emoji,
    required this.description,
    required this.storeId,
    this.isAvailable = true,
  });
}

class ProductSaleModel {
  final String productId;
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
