import 'package:mixue_manager/core/constants/enums.dart';

class UserModel {
  final int id;
  final String username;
  final String passwordHash;
  final String fullName;
  final String? phone;
  final String? email;
  final UserRole role;
  final int? storeId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status; // 'active' | 'inactive'
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.fullName,
    this.phone,
    this.email,
    required this.role,
    this.storeId,
    this.startDate,
    this.endDate,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  UserModel copyWith({
    int? id,
    String? username,
    String? passwordHash,
    String? fullName,
    String? phone,
    String? email,
    UserRole? role,
    int? storeId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      storeId: storeId ?? this.storeId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
