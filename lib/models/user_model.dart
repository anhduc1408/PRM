import 'package:mixue_manager/core/constants/enums.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String? storeId;
  final String? storeName;
  final String? phone;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.storeId,
    this.storeName,
    this.phone,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    UserRole? role,
    String? storeId,
    String? storeName,
    String? phone,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      phone: phone ?? this.phone,
    );
  }
}
