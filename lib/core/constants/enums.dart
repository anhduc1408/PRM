enum UserRole {
  ceoAdmin,
  itAdmin,
  storeManager,
  inventoryChecker,
  staff;

  String get displayName {
    switch (this) {
      case UserRole.ceoAdmin:          return 'CEO Admin';
      case UserRole.itAdmin:           return 'IT Admin';
      case UserRole.storeManager:      return 'Cửa hàng trưởng';
      case UserRole.inventoryChecker:  return 'Kiểm kho';
      case UserRole.staff:             return 'Staff';
    }
  }

  String get description {
    switch (this) {
      case UserRole.ceoAdmin:          return 'Quản lý hệ thống toàn chuỗi';
      case UserRole.itAdmin:           return 'Quản lý nhân sự & phân quyền';
      case UserRole.storeManager:      return 'Quản lý hoạt động cửa hàng';
      case UserRole.inventoryChecker:  return 'Kiểm tra & quản lý kho hàng';
      case UserRole.staff:             return 'Nhân viên cửa hàng';
    }
  }
}

enum PeriodFilter {
  day,
  week,
  month;

  String get label {
    switch (this) {
      case PeriodFilter.day:
        return 'Hôm nay';
      case PeriodFilter.week:
        return 'Tuần này';
      case PeriodFilter.month:
        return 'Tháng này';
    }
  }
}

enum PaymentMethod {
  cash,
  transfer;

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tiền mặt';
      case PaymentMethod.transfer:
        return 'Chuyển khoản';
    }
  }
}

enum ShiftType {
  morning,
  afternoon,
  evening;

  String get label {
    switch (this) {
      case ShiftType.morning:
        return 'Ca sáng (6:00 - 14:00)';
      case ShiftType.afternoon:
        return 'Ca chiều (14:00 - 22:00)';
      case ShiftType.evening:
        return 'Ca tối (22:00 - 06:00)';
    }
  }

  String get shortLabel {
    switch (this) {
      case ShiftType.morning:
        return 'Ca Sáng';
      case ShiftType.afternoon:
        return 'Ca Chiều';
      case ShiftType.evening:
        return 'Ca Tối';
    }
  }
}

enum ProductCategory {
  iceCream,
  tea,
  coffee,
  dessert,
  other;

  String get label {
    switch (this) {
      case ProductCategory.iceCream:
        return 'Kem';
      case ProductCategory.tea:
        return 'Trà';
      case ProductCategory.coffee:
        return 'Cà phê';
      case ProductCategory.dessert:
        return 'Tráng miệng';
      case ProductCategory.other:
        return 'Khác';
    }
  }
}
