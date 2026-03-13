class WarehouseModel {
  final int id;
  final String code;
  final String name;
  final String type; // 'main' | 'store'
  final int storeId;
  final String? address;
  final String? phone;
  final int? managerUserId;
  final String status; // 'active' | 'inactive'
  final DateTime createdAt;
  final DateTime updatedAt;

  // For display — joined from users/stores
  final String? storeName;
  final String? managerName;

  const WarehouseModel({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.storeId,
    this.address,
    this.phone,
    this.managerUserId,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    this.storeName,
    this.managerName,
  });
}
