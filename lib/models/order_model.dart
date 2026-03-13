class SalesOrderItemModel {
  final int id;
  final int salesOrderId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  // For display
  final String? productName;

  const SalesOrderItemModel({
    required this.id,
    required this.salesOrderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.productName,
  });

  double get subtotal => lineTotal;
}

class PaymentModel {
  final int id;
  final int salesOrderId;
  final String paymentMethod; // 'cash' | 'transfer' | 'card'
  final double amount;
  final DateTime paidAt;

  const PaymentModel({
    required this.id,
    required this.salesOrderId,
    required this.paymentMethod,
    required this.amount,
    required this.paidAt,
  });
}

class SalesOrderModel {
  final int id;
  final String orderNo;
  final int storeId;
  final int staffUserId;
  final DateTime orderDate;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final String paymentStatus; // 'pending' | 'paid' | 'cancelled'
  final String? note;
  final DateTime createdAt;

  // For display
  final String? staffName;
  final String? storeName;
  List<SalesOrderItemModel> items;
  List<PaymentModel> payments;

  SalesOrderModel({
    required this.id,
    required this.orderNo,
    required this.storeId,
    required this.staffUserId,
    required this.orderDate,
    required this.totalAmount,
    this.discountAmount = 0,
    required this.finalAmount,
    this.paymentStatus = 'paid',
    this.note,
    required this.createdAt,
    this.staffName,
    this.storeName,
    this.items = const [],
    this.payments = const [],
  });
}
