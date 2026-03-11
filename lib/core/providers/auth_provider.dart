import 'package:flutter/material.dart';
import '../constants/enums.dart';
import '../../models/user_model.dart';
import '../../data/database_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  String? _errorMessage;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  String?   get errorMessage => _errorMessage;
  bool      get isLoggedIn   => _currentUser != null;
  bool      get isLoading    => _isLoading;

  Future<bool> login(String email, String password) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final user = await DatabaseService.instance.getUser(email, password);
      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Email hoặc mật khẩu không đúng';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Lỗi kết nối database: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> updateUserRole(
      String userId, UserRole newRole, String? storeId, String? storeName) async {
    await DatabaseService.instance.updateUserRole(
      userId,
      _roleToString(newRole),
      storeId,
      storeName,
    );
    if (_currentUser?.id == userId) {
      _currentUser = _currentUser!.copyWith(
        role: newRole,
        storeId: storeId,
        storeName: storeName,
      );
      notifyListeners();
    }
  }

  String _roleToString(UserRole r) {
    switch (r) {
      case UserRole.ceoAdmin:         return 'ceoAdmin';
      case UserRole.itAdmin:          return 'itAdmin';
      case UserRole.storeManager:     return 'storeManager';
      case UserRole.inventoryChecker: return 'inventoryChecker';
      case UserRole.staff:            return 'staff';
    }
  }
}
