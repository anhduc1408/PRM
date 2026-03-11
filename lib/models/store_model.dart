class StoreModel {
  final String id;
  final String name;
  final String address;
  final String district;
  final String phone;
  final bool isActive;
  final DateTime openedAt;

  const StoreModel({
    required this.id,
    required this.name,
    required this.address,
    required this.district,
    required this.phone,
    required this.isActive,
    required this.openedAt,
  });
}
