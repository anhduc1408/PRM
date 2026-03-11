import 'package:mixue_manager/core/constants/enums.dart';

class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
  });

  double get subtotal => price * quantity;
}

class OrderModel {
  final String id;
  final DateTime createdAt;
  final List<OrderItem> items;
  final PaymentMethod paymentMethod;
  final String staffId;
  final String staffName;
  final String storeId;
  final ShiftType shift;
  final String? notes;

  const OrderModel({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.paymentMethod,
    required this.staffId,
    required this.staffName,
    required this.storeId,
    required this.shift,
    this.notes,
  });

  double get totalAmount => items.fold(0, (sum, item) => sum + item.subtotal);
}
