import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/user_model.dart';
import '../models/store_model.dart';
import '../models/warehouse_model.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/warehouse_inventory_model.dart';
import '../models/stock_transfer_model.dart';
import '../models/order_model.dart';
import '../models/work_schedule_model.dart';
import '../models/notification_model.dart';
import '../models/inventory_log_model.dart';
import '../core/constants/enums.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  // ─── OPEN ─────────────────────────────────────────────────────────────────
  Future<Database> _open() async {
    final String path;
    if (kIsWeb) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, 'mixue_v2.db');
    }
    return openDatabase(path, version: 3, onCreate: (db, v) async {
      await _createTables(db);
      await _seedData(db);
    }, onUpgrade: (db, oldV, newV) async {
      if (oldV < 3) {
        try {
          await db.execute('ALTER TABLE warehouse_inventory ADD COLUMN expiry_date TEXT;');
        } catch (e) {
          // ignore error if column already exists
        }
      }
    });
  }

  // ─── CREATE TABLES ────────────────────────────────────────────────────────
  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        full_name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        role TEXT NOT NULL,
        store_id INTEGER,
        start_date TEXT,
        end_date TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (store_id) REFERENCES stores(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'store',
        store_id INTEGER NOT NULL,
        address TEXT,
        phone TEXT,
        manager_user_id INTEGER,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (store_id) REFERENCES stores(id),
        FOREIGN KEY (manager_user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT NOT NULL UNIQUE,
        barcode TEXT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        unit TEXT NOT NULL DEFAULT 'cup',
        cost_price REAL NOT NULL DEFAULT 0,
        selling_price REAL NOT NULL DEFAULT 0,
        emoji TEXT NOT NULL DEFAULT '🧋',
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouse_inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        warehouse_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        min_quantity INTEGER NOT NULL DEFAULT 10,
        expiry_date TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (product_id) REFERENCES products(id),
        UNIQUE(warehouse_id, product_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_warehouse_id INTEGER NOT NULL,
        to_warehouse_id INTEGER NOT NULL,
        requested_by INTEGER NOT NULL,
        approved_by INTEGER,
        status TEXT NOT NULL DEFAULT 'pending',
        note TEXT,
        created_at TEXT NOT NULL,
        received_at TEXT,
        FOREIGN KEY (from_warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (to_warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (requested_by) REFERENCES users(id),
        FOREIGN KEY (approved_by) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transfer_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        estimate_quantity INTEGER NOT NULL DEFAULT 0,
        actual_quantity INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (transfer_id) REFERENCES stock_transfers(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_no TEXT NOT NULL UNIQUE,
        store_id INTEGER NOT NULL,
        staff_user_id INTEGER NOT NULL,
        order_date TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0,
        discount_amount REAL NOT NULL DEFAULT 0,
        final_amount REAL NOT NULL DEFAULT 0,
        payment_status TEXT NOT NULL DEFAULT 'paid',
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (store_id) REFERENCES stores(id),
        FOREIGN KEY (staff_user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sales_order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        line_total REAL NOT NULL,
        FOREIGN KEY (sales_order_id) REFERENCES sales_orders(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sales_order_id INTEGER NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        amount REAL NOT NULL,
        paid_at TEXT NOT NULL,
        FOREIGN KEY (sales_order_id) REFERENCES sales_orders(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS work_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shift_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        work_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'scheduled',
        assigned_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (shift_id) REFERENCES work_shifts(id),
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (assigned_by) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        target_user_id INTEGER,
        store_id INTEGER,
        product_id INTEGER,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (target_user_id) REFERENCES users(id),
        FOREIGN KEY (store_id) REFERENCES stores(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_id INTEGER,
        product_id INTEGER NOT NULL,
        change_type TEXT NOT NULL,
        quantity_before INTEGER NOT NULL,
        quantity_change INTEGER NOT NULL,
        quantity_after INTEGER NOT NULL,
        reference_type TEXT NOT NULL,
        reference_id INTEGER,
        order_id INTEGER,
        created_by INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (order_id) REFERENCES sales_orders(id),
        FOREIGN KEY (created_by) REFERENCES users(id)
      )
    ''');
  }

  // ─── SEED DATA ────────────────────────────────────────────────────────────
  Future<void> _seedData(Database db) async {
    final now = DateTime.now().toIso8601String();
    final rng = Random();

    // Stores
    await db.insert('stores', {'code': 'STR001', 'name': 'Tạp Hóa Minh Châu - Quận 1', 'address': '45 Nguyễn Trãi, Q.1, TP.HCM', 'phone': '028-1234-5678', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('stores', {'code': 'STR002', 'name': 'Tạp Hóa Minh Châu - Quận 5', 'address': '128 Trần Hưng Đạo, Q.5, TP.HCM', 'phone': '028-2345-6789', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('stores', {'code': 'STR003', 'name': 'Tạp Hóa Minh Châu - Bình Thạnh', 'address': '67 Đinh Bộ Lĩnh, Bình Thạnh, TP.HCM', 'phone': '028-3456-7890', 'status': 'active', 'created_at': now, 'updated_at': now});

    // Users
    await db.insert('users', {'username': 'ceo', 'password_hash': '123456', 'full_name': 'Nguyễn Minh Châu', 'email': 'ceo@minhchau.vn', 'role': 'ceoAdmin', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('users', {'username': 'it', 'password_hash': '123456', 'full_name': 'IT Admin', 'email': 'it@minhchau.vn', 'role': 'itAdmin', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('users', {'username': 'staff1', 'password_hash': '123456', 'full_name': 'Nguyễn Văn An', 'email': 'staff1@minhchau.vn', 'role': 'staff', 'store_id': 1, 'phone': '0901234567', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('users', {'username': 'staff2', 'password_hash': '123456', 'full_name': 'Trần Thị Bình', 'email': 'staff2@minhchau.vn', 'role': 'staff', 'store_id': 2, 'phone': '0912345678', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('users', {'username': 'manager1', 'password_hash': '123456', 'full_name': 'Lê Văn Quản', 'email': 'manager1@minhchau.vn', 'role': 'storeManager', 'store_id': 1, 'phone': '0923456789', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('users', {'username': 'checker1', 'password_hash': '123456', 'full_name': 'Phạm Thị Kiểm', 'email': 'checker1@minhchau.vn', 'role': 'inventoryChecker', 'store_id': 1, 'phone': '0934567890', 'status': 'active', 'created_at': now, 'updated_at': now});
    
    // Add more mock staff for store 1
    await db.insert('users', {'username': 'staff3', 'password_hash': '123456', 'full_name': 'Hoàng Văn Cường', 'email': 'staff3@minhchau.vn', 'role': 'staff', 'store_id': 1, 'phone': '0945678901', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('users', {'username': 'staff4', 'password_hash': '123456', 'full_name': 'Đinh Thị Dung', 'email': 'staff4@minhchau.vn', 'role': 'staff', 'store_id': 1, 'phone': '0956789012', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('users', {'username': 'staff5', 'password_hash': '123456', 'full_name': 'Cao Văn Em', 'email': 'staff5@minhchau.vn', 'role': 'staff', 'store_id': 1, 'phone': '0967890123', 'status': 'active', 'created_at': now, 'updated_at': now});

    // Warehouses
    await db.insert('warehouses', {'code': 'WH001', 'name': 'Kho Tổng Trung Tâm', 'type': 'main', 'store_id': 1, 'address': '12 Lê Lai, Q.1, TP.HCM', 'manager_user_id': 5, 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('warehouses', {'code': 'WH002', 'name': 'Kho Chi Nhánh Q.1', 'type': 'store', 'store_id': 1, 'manager_user_id': 5, 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('warehouses', {'code': 'WH003', 'name': 'Kho Chi Nhánh Q.5', 'type': 'store', 'store_id': 2, 'status': 'active', 'created_at': now, 'updated_at': now});

    // Categories
    await db.insert('categories', {'name': 'Thực phẩm khô', 'description': 'Gạo, mì, bún, miến, đậu các loại', 'created_at': now, 'updated_at': now});
    await db.insert('categories', {'name': 'Đồ uống', 'description': 'Nước ngọt, bia, nước trái cây, trà đóng chai', 'created_at': now, 'updated_at': now});
    await db.insert('categories', {'name': 'Gia vị & Dầu ăn', 'description': 'Nước mắm, muối, đường, dầu ăn, tương, ớt', 'created_at': now, 'updated_at': now});
    await db.insert('categories', {'name': 'Bánh kẹo & Snack', 'description': 'Bánh quy, kẹo, snack, chocolate, mứt', 'created_at': now, 'updated_at': now});
    await db.insert('categories', {'name': 'Hàng gia dụng', 'description': 'Xà phòng, dầu gội, bột giặt, nước rửa chén', 'created_at': now, 'updated_at': now});

    // Products
    final products = [
      {'sku': 'DRY001', 'name': 'Gạo ST25 (5kg)', 'category_id': 1, 'unit': 'túi', 'cost_price': 85000.0, 'selling_price': 105000.0, 'emoji': '🌾'},
      {'sku': 'DRY002', 'name': 'Mì Hảo Hảo (thùng 30 gói)', 'category_id': 1, 'unit': 'thùng', 'cost_price': 95000.0, 'selling_price': 120000.0, 'emoji': '🍜'},
      {'sku': 'DRY003', 'name': 'Bún gạo khô (500g)', 'category_id': 1, 'unit': 'gói', 'cost_price': 18000.0, 'selling_price': 25000.0, 'emoji': '🍝'},
      {'sku': 'BEV001', 'name': 'Bia Tiger (thùng 24 lon)', 'category_id': 2, 'unit': 'thùng', 'cost_price': 280000.0, 'selling_price': 340000.0, 'emoji': '🍺'},
      {'sku': 'BEV002', 'name': 'Nước Pepsi (lốc 6 lon)', 'category_id': 2, 'unit': 'lốc', 'cost_price': 45000.0, 'selling_price': 58000.0, 'emoji': '🥤'},
      {'sku': 'BEV003', 'name': 'Trà Ô Long C2 (lốc 6 chai)', 'category_id': 2, 'unit': 'lốc', 'cost_price': 38000.0, 'selling_price': 50000.0, 'emoji': '🧃'},
      {'sku': 'SPC001', 'name': 'Nước mắm Phú Quốc (500ml)', 'category_id': 3, 'unit': 'chai', 'cost_price': 28000.0, 'selling_price': 38000.0, 'emoji': '🫙'},
      {'sku': 'SPC002', 'name': 'Dầu ăn Neptune (2 lít)', 'category_id': 3, 'unit': 'chai', 'cost_price': 68000.0, 'selling_price': 85000.0, 'emoji': '🫒'},
      {'sku': 'SNK001', 'name': 'Bánh quy Marie (hộp 400g)', 'category_id': 4, 'unit': 'hộp', 'cost_price': 32000.0, 'selling_price': 42000.0, 'emoji': '🍪'},
      {'sku': 'HHD001', 'name': 'Bột giặt OMO (3kg)', 'category_id': 5, 'unit': 'túi', 'cost_price': 95000.0, 'selling_price': 120000.0, 'emoji': '🧺'},
    ];
    for (final prod in products) {
      await db.insert('products', {...prod, 'status': 'active', 'created_at': now, 'updated_at': now});
    }

    // Warehouse Inventory
    for (int wh = 1; wh <= 3; wh++) {
      for (int prod = 1; prod <= 10; prod++) {
        final expiry = DateTime.now().add(Duration(days: rng.nextInt(180) + 30));
        await db.insert('warehouse_inventory', {
          'warehouse_id': wh, 'product_id': prod,
          'quantity': rng.nextInt(500) + 150, 'min_quantity': 50, 
          'expiry_date': expiry.toIso8601String(), 'updated_at': now,
        });
      }
    }

    // Work Shifts
    await db.insert('work_shifts', {'name': 'Ca Sáng', 'start_time': '06:00', 'end_time': '14:00', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('work_shifts', {'name': 'Ca Chiều', 'start_time': '14:00', 'end_time': '22:00', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('work_shifts', {'name': 'Ca Tối', 'start_time': '22:00', 'end_time': '06:00', 'status': 'active', 'created_at': now, 'updated_at': now});

    // Shift Assignments (last 30 days to next 14 days)
    for (int day = -30; day <= 14; day++) {
      final date = DateTime.now().add(Duration(days: day));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
      for (final userId in [3, 4, 5, 7, 8, 9]) {
        // Randomly skip some days so staff don't work every day
        if (rng.nextDouble() < 0.2) continue;
        
        await db.insert('shift_assignments', {
          'shift_id': rng.nextInt(3) + 1, 'user_id': userId,
          'work_date': dateStr, 'status': day < 0 ? 'completed' : 'scheduled',
          'assigned_by': 5, 'created_at': now,
        });
      }
    }

    // Sales Orders (last 45 days)
    int orderCounter = 1;
    for (int day = -45; day <= 0; day++) {
      final date = DateTime.now().add(Duration(days: day));
      final ordersPerDay = rng.nextInt(20) + 10; // 10 to 30 orders per day
      
      for (int i = 0; i < ordersPerDay; i++) {
        final storeId = rng.nextInt(2) + 1; // 1 or 2
        final prodCount = rng.nextInt(4) + 1; // 1 to 4 products per order
        
        // Pick a staff user for the store
        final staffUserId = storeId == 1 
            ? [3, 7, 8, 9][rng.nextInt(4)] // Store 1 staff
            : 4; // Store 2 staff

        double total = 0;
        final orderNo = 'ORD${orderCounter.toString().padLeft(6,'0')}';
        
        // Random hour for the order within the day
        final orderDate = DateTime(date.year, date.month, date.day, rng.nextInt(15) + 7, rng.nextInt(60));
        
        final orderId = await db.insert('sales_orders', {
          'order_no': orderNo, 'store_id': storeId, 'staff_user_id': staffUserId,
          'order_date': orderDate.toIso8601String(), 'total_amount': 0,
          'discount_amount': 0, 'final_amount': 0, 'payment_status': 'paid', 'created_at': orderDate.toIso8601String(),
        });
        
        for (int j = 0; j < prodCount; j++) {
          final prodId = rng.nextInt(10) + 1;
          final qty = rng.nextInt(4) + 1; // 1 to 4 quantity
          final price = products[prodId - 1]['selling_price'] as double;
          final lineTotal = price * qty;
          total += lineTotal;
          await db.insert('sales_order_items', {
            'sales_order_id': orderId, 'product_id': prodId,
            'quantity': qty, 'unit_price': price, 'line_total': lineTotal,
          });
        }
        
        await db.update('sales_orders', {'total_amount': total, 'final_amount': total}, where: 'id = ?', whereArgs: [orderId]);
        final method = rng.nextDouble() < 0.6 ? 'cash' : 'transfer'; // 60% cash, 40% transfer
        await db.insert('payments', {
          'sales_order_id': orderId, 'payment_method': method, 'amount': total, 'paid_at': orderDate.toIso8601String(),
        });
        orderCounter++;
      }
    }

    // Stock Transfers - du lieu mau de checker test
    final t1Date = DateTime.now().subtract(const Duration(hours: 3));
    final t1Id = await db.insert('stock_transfers', {
      'from_warehouse_id': 1, 'to_warehouse_id': 2, 'requested_by': 6,
      'status': 'in_transit', 'note': 'Bo sung hang cuoi tuan',
      'created_at': t1Date.toIso8601String(),
    });
    await db.insert('stock_transfer_items', {'transfer_id': t1Id, 'product_id': 1, 'estimate_quantity': 50, 'actual_quantity': 0});
    await db.insert('stock_transfer_items', {'transfer_id': t1Id, 'product_id': 4, 'estimate_quantity': 30, 'actual_quantity': 0});
    await db.insert('stock_transfer_items', {'transfer_id': t1Id, 'product_id': 7, 'estimate_quantity': 20, 'actual_quantity': 0});

    final t2Date = DateTime.now().subtract(const Duration(hours: 1));
    final t2Id = await db.insert('stock_transfers', {
      'from_warehouse_id': 1, 'to_warehouse_id': 2, 'requested_by': 6,
      'status': 'pending', 'note': null,
      'created_at': t2Date.toIso8601String(),
    });
    await db.insert('stock_transfer_items', {'transfer_id': t2Id, 'product_id': 2, 'estimate_quantity': 25, 'actual_quantity': 0});
    await db.insert('stock_transfer_items', {'transfer_id': t2Id, 'product_id': 9, 'estimate_quantity': 15, 'actual_quantity': 0});

    final t3Date = DateTime.now().subtract(const Duration(days: 2));
    final t3Id = await db.insert('stock_transfers', {
      'from_warehouse_id': 1, 'to_warehouse_id': 3, 'requested_by': 6,
      'approved_by': 6, 'status': 'received', 'note': 'Hang giao kho Q3',
      'created_at': t3Date.toIso8601String(),
      'received_at': t3Date.add(const Duration(hours: 5)).toIso8601String(),
    });
    await db.insert('stock_transfer_items', {'transfer_id': t3Id, 'product_id': 3, 'estimate_quantity': 40, 'actual_quantity': 38});
    await db.insert('stock_transfer_items', {'transfer_id': t3Id, 'product_id': 6, 'estimate_quantity': 20, 'actual_quantity': 20});

    // ─── Seed Notifications ───────────────────────────────────────────────────
    // User IDs: 1=ceo, 2=it, 3=staff1(Q1), 4=staff2(Q5), 5=manager1(Q1), 6=checker1(Q1), 7=staff3, 8=staff4, 9=staff5
    // Store IDs: 1=Q1, 2=Q5, 3=Bình Thạnh

    final n1 = DateTime.now().subtract(const Duration(days: 7));
    final n2 = DateTime.now().subtract(const Duration(days: 5));
    final n3 = DateTime.now().subtract(const Duration(days: 3));
    final n4 = DateTime.now().subtract(const Duration(days: 2));
    final n5 = DateTime.now().subtract(const Duration(hours: 20));
    final n6 = DateTime.now().subtract(const Duration(hours: 10));
    final n7 = DateTime.now().subtract(const Duration(hours: 5));
    final n8 = DateTime.now().subtract(const Duration(hours: 2));
    final n9 = DateTime.now().subtract(const Duration(minutes: 45));
    final n10 = DateTime.now().subtract(const Duration(minutes: 10));

    // --- Thông báo hệ thống (system) ---
    await db.insert('notifications', {
      'type': 'system', 'title': 'Tài khoản của bạn đã được tạo',
      'content': 'Chào mừng Nguyễn Văn An! Vai trò: Nhân viên tại Tạp Hóa Minh Châu - Quận 1. Tên đăng nhập: staff1. Mật khẩu: 123456',
      'target_user_id': 3, 'store_id': 1, 'is_read': 1, 'created_at': n1.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'system', 'title': 'Tài khoản của bạn đã được tạo',
      'content': 'Chào mừng Trần Thị Bình! Vai trò: Nhân viên tại Tạp Hóa Minh Châu - Quận 5. Tên đăng nhập: staff2. Mật khẩu: 123456',
      'target_user_id': 4, 'store_id': 2, 'is_read': 1, 'created_at': n1.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'system', 'title': 'Tài khoản của bạn đã được tạo',
      'content': 'Chào mừng Lê Văn Quản! Vai trò: Quản lý cửa hàng tại Tạp Hóa Minh Châu - Quận 1. Tên đăng nhập: manager1. Mật khẩu: 123456',
      'target_user_id': 5, 'store_id': 1, 'is_read': 1, 'created_at': n1.toIso8601String(),
    });

    // --- Thông báo cập nhật vai trò (role_update) ---
    await db.insert('notifications', {
      'type': 'role_update', 'title': 'Thông tin tài khoản của bạn đã được cập nhật',
      'content': 'IT Admin đã thay đổi: Cửa hàng: Không có cửa hàng → Tạp Hóa Minh Châu - Quận 1',
      'target_user_id': 3, 'store_id': 1, 'is_read': 1, 'created_at': n2.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'role_update', 'title': 'Nhân viên mới được thêm vào cửa hàng của bạn',
      'content': 'Nguyễn Văn An (Nhân viên) đã được thêm vào Tạp Hóa Minh Châu - Quận 1',
      'target_user_id': 5, 'store_id': 1, 'is_read': 1, 'created_at': n2.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'role_update', 'title': 'Thông tin tài khoản của bạn đã được cập nhật',
      'content': 'IT Admin đã thay đổi: Vai trò: Nhân viên → Kiểm kho',
      'target_user_id': 6, 'store_id': 1, 'is_read': 0, 'created_at': n3.toIso8601String(),
    });

    // --- Thông báo reset mật khẩu ---
    await db.insert('notifications', {
      'type': 'system', 'title': 'Mật khẩu của bạn đã được đặt lại',
      'content': 'IT Admin đã reset mật khẩu của bạn về 123456. Vui lòng đổi mật khẩu sau khi đăng nhập.',
      'target_user_id': 7, 'is_read': 1, 'created_at': n3.toIso8601String(),
    });

    // --- Thông báo sắp hết hàng (low_stock) ---
    await db.insert('notifications', {
      'type': 'low_stock', 'title': 'Sắp hết hàng: Gạo ST25 (5kg)',
      'content': 'Gạo ST25 (5kg) tại Tạp Hóa Minh Châu - Quận 1 sắp hết hàng. Số lượng còn lại: 12 túi',
      'target_user_id': 5, 'store_id': 1, 'product_id': 1, 'is_read': 0, 'created_at': n4.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'low_stock', 'title': 'Sắp hết hàng: Gạo ST25 (5kg)',
      'content': 'Gạo ST25 (5kg) tại Tạp Hóa Minh Châu - Quận 1 sắp hết hàng. Số lượng còn lại: 12 túi',
      'target_user_id': 6, 'store_id': 1, 'product_id': 1, 'is_read': 0, 'created_at': n4.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'low_stock', 'title': 'Sắp hết hàng: Trà Ô Long C2',
      'content': 'Trà Ô Long C2 (lốc 6 chai) tại Tạp Hóa Minh Châu - Quận 5 sắp hết hàng. Số lượng còn lại: 8 lốc',
      'target_user_id': 6, 'store_id': 2, 'product_id': 6, 'is_read': 1, 'created_at': n4.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'low_stock', 'title': 'Sắp hết hàng: Nước mắm Phú Quốc',
      'content': 'Nước mắm Phú Quốc (500ml) tại Tạp Hóa Minh Châu - Quận 1 sắp hết hàng. Số lượng còn lại: 5 chai',
      'target_user_id': 5, 'store_id': 1, 'product_id': 7, 'is_read': 0, 'created_at': n5.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'low_stock', 'title': 'Sắp hết hàng: Nước mắm Phú Quốc',
      'content': 'Nước mắm Phú Quốc (500ml) tại Tạp Hóa Minh Châu - Quận 1 sắp hết hàng. Số lượng còn lại: 5 chai',
      'target_user_id': 6, 'store_id': 1, 'product_id': 7, 'is_read': 0, 'created_at': n5.toIso8601String(),
    });

    // --- Thông báo chuyển kho (transfer) ---
    await db.insert('notifications', {
      'type': 'transfer', 'title': 'Phiếu chuyển kho mới cần duyệt',
      'content': 'Phiếu chuyển kho từ Kho Tổng Trung Tâm → Kho Chi Nhánh Q.1 đang chờ xác nhận. 3 mặt hàng, ~100 đơn vị.',
      'target_user_id': 5, 'store_id': 1, 'is_read': 0, 'created_at': n6.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'transfer', 'title': 'Hàng đã được gửi đến kho của bạn',
      'content': 'Phiếu chuyển kho đang vận chuyển: Kho Tổng Trung Tâm → Kho Chi Nhánh Q.1. Dự kiến 3 mặt hàng.',
      'target_user_id': 6, 'store_id': 1, 'is_read': 1, 'created_at': n6.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'transfer', 'title': 'Xác nhận nhận hàng thành công',
      'content': 'Đã nhận hàng từ Kho Tổng. Bún gạo khô: 38/40 gói, Trà Ô Long C2: 20/20 lốc.',
      'target_user_id': 6, 'store_id': 1, 'is_read': 1, 'created_at': n7.toIso8601String(),
    });

    // --- Thông báo mới nhất (chưa đọc) ---
    await db.insert('notifications', {
      'type': 'role_update', 'title': 'Thông tin tài khoản của bạn đã được cập nhật',
      'content': 'IT Admin đã thay đổi: Cửa hàng: Tạp Hóa Minh Châu - Quận 1 → Tạp Hóa Minh Châu - Quận 5',
      'target_user_id': 8, 'store_id': 2, 'is_read': 0, 'created_at': n8.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'role_update', 'title': 'Nhân viên mới được thêm vào cửa hàng của bạn',
      'content': 'Đinh Thị Dung (Nhân viên) đã được thêm vào Tạp Hóa Minh Châu - Quận 1',
      'target_user_id': 5, 'store_id': 2, 'is_read': 0, 'created_at': n8.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'low_stock', 'title': 'Sắp hết hàng: Bột giặt OMO',
      'content': 'Bột giặt OMO (3kg) tại Tạp Hóa Minh Châu - Quận 1 sắp hết hàng. Số lượng còn lại: 3 túi',
      'target_user_id': 5, 'store_id': 1, 'product_id': 10, 'is_read': 0, 'created_at': n9.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'low_stock', 'title': 'Sắp hết hàng: Bột giặt OMO',
      'content': 'Bột giặt OMO (3kg) tại Tạp Hóa Minh Châu - Quận 1 sắp hết hàng. Số lượng còn lại: 3 túi',
      'target_user_id': 6, 'store_id': 1, 'product_id': 10, 'is_read': 0, 'created_at': n9.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'system', 'title': 'Hệ thống bảo trì định kỳ',
      'content': 'Hệ thống sẽ bảo trì vào 23:00 tối nay (20/03/2026). Thời gian dự kiến: 30 phút.',
      'target_user_id': 1, 'is_read': 0, 'created_at': n10.toIso8601String(),
    });
    await db.insert('notifications', {
      'type': 'system', 'title': 'Hệ thống bảo trì định kỳ',
      'content': 'Hệ thống sẽ bảo trì vào 23:00 tối nay (20/03/2026). Thời gian dự kiến: 30 phút.',
      'target_user_id': 2, 'is_read': 0, 'created_at': n10.toIso8601String(),
    });
  }

  // ─── USER QUERIES ─────────────────────────────────────────────────────────
  Future<UserModel?> getUserByCredentials(String username, String password) async {
    final db = await database;
    final rows = await db.query('users',
        where: 'username = ? AND password_hash = ? AND status = ?',
        whereArgs: [username.trim(), password.trim(), 'active'], limit: 1);
    if (rows.isEmpty) return null;
    return _mapUser(rows.first);
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final rows = await db.query('users', orderBy: 'full_name ASC');
    return rows.map(_mapUser).toList();
  }

  Future<List<UserModel>> getUsersByStore(int storeId) async {
    final db = await database;
    final rows = await db.query('users', where: 'store_id = ?', whereArgs: [storeId], orderBy: 'full_name ASC');
    return rows.map(_mapUser).toList();
  }

  Future<void> insertUser(UserModel user) async {
    final db = await database;
    await db.insert('users', _userToMap(user), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateUser(UserModel user) async {
    final db = await database;
    await db.update('users', {
      'full_name': user.fullName, 'email': user.email, 'phone': user.phone,
      'role': _roleToString(user.role), 'store_id': user.storeId, 'status': user.status,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> resetPassword(int userId) async {
    final db = await database;
    await db.update('users', {'password_hash': '123456', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [userId]);
  }

  /// Đảm bảo tất cả tài khoản demo tồn tại trong DB.
  /// Dùng INSERT OR IGNORE (UNIQUE trên username) → an toàn gọi mỗi lần khởi động.
  Future<void> ensureDemoUsers() async {
    final db  = await database;
    final now = DateTime.now().toIso8601String();

    final storeRows = await db.query('stores', columns: ['id'], limit: 1);
    final sId = storeRows.isNotEmpty ? storeRows.first['id'] as int : 1;

    final demos = [
      {'username': 'ceo1',     'password_hash': '123456', 'full_name': 'Nguyen Minh Chau', 'email': 'ceo1@minhchau.vn',     'role': 'ceoAdmin',         'store_id': null, 'status': 'active', 'created_at': now, 'updated_at': now},
      {'username': 'it1',      'password_hash': '123456', 'full_name': 'IT Admin',          'email': 'it1@minhchau.vn',      'role': 'itAdmin',          'store_id': null, 'status': 'active', 'created_at': now, 'updated_at': now},
      {'username': 'manager1', 'password_hash': '123456', 'full_name': 'Le Van Quan',       'email': 'manager1@minhchau.vn', 'role': 'storeManager',     'store_id': sId,  'status': 'active', 'created_at': now, 'updated_at': now},
      {'username': 'checker1', 'password_hash': '123456', 'full_name': 'Pham Thi Kiem',     'email': 'checker1@minhchau.vn', 'role': 'inventoryChecker', 'store_id': sId,  'status': 'active', 'created_at': now, 'updated_at': now},
      {'username': 'staff1',   'password_hash': '123456', 'full_name': 'Nguyen Van An',     'email': 'staff1@minhchau.vn',   'role': 'staff',            'store_id': sId,  'status': 'active', 'created_at': now, 'updated_at': now},
    ];

    for (final u in demos) {
      await db.insert('users', u, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ─── STORE QUERIES ────────────────────────────────────────────────────────
  Future<List<StoreModel>> getAllStores() async {
    final db = await database;
    final rows = await db.query('stores', orderBy: 'name ASC');
    return rows.map(_mapStore).toList();
  }

  Future<StoreModel?> getStore(int id) async {
    final db = await database;
    final rows = await db.query('stores', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _mapStore(rows.first);
  }

  // ─── WAREHOUSE QUERIES ────────────────────────────────────────────────────
  Future<List<WarehouseModel>> getAllWarehouses() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT w.*, s.name as store_name, u.full_name as manager_name
      FROM warehouses w
      LEFT JOIN stores s ON s.id = w.store_id
      LEFT JOIN users u ON u.id = w.manager_user_id
      ORDER BY w.name ASC
    ''');
    return rows.map(_mapWarehouse).toList();
  }

  Future<List<WarehouseModel>> getWarehousesByStore(int storeId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT w.*, s.name as store_name, u.full_name as manager_name
      FROM warehouses w
      LEFT JOIN stores s ON s.id = w.store_id
      LEFT JOIN users u ON u.id = w.manager_user_id
      WHERE w.store_id = ?
      ORDER BY w.name ASC
    ''', [storeId]);
    return rows.map(_mapWarehouse).toList();
  }

  // ─── CATEGORY QUERIES ─────────────────────────────────────────────────────
  Future<List<CategoryModel>> getAllCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map(_mapCategory).toList();
  }

  // ─── PRODUCT QUERIES ──────────────────────────────────────────────────────
  Future<List<ProductModel>> getAllProducts() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name
      FROM products p LEFT JOIN categories c ON c.id = p.category_id
      ORDER BY p.name ASC
    ''');
    return rows.map(_mapProduct).toList();
  }

  Future<List<ProductModel>> getProductsActive() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name
      FROM products p LEFT JOIN categories c ON c.id = p.category_id
      WHERE p.status = 'active'
      ORDER BY p.name ASC
    ''');
    return rows.map(_mapProduct).toList();
  }

  // ─── INVENTORY QUERIES ────────────────────────────────────────────────────
  Future<List<WarehouseInventoryModel>> getInventoryByWarehouse(int warehouseId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT wi.*, p.name as product_name, p.sku as product_sku, w.name as warehouse_name
      FROM warehouse_inventory wi
      JOIN products p ON p.id = wi.product_id
      JOIN warehouses w ON w.id = wi.warehouse_id
      WHERE wi.warehouse_id = ?
      ORDER BY p.name ASC
    ''', [warehouseId]);
    return rows.map(_mapInventory).toList();
  }

  Future<List<WarehouseInventoryModel>> getLowStockItems({int? storeId}) async {
    final db = await database;
    final storeFilter = storeId != null ? 'AND w.store_id = $storeId' : '';
    final rows = await db.rawQuery('''
      SELECT wi.*, p.name as product_name, p.sku as product_sku, w.name as warehouse_name
      FROM warehouse_inventory wi
      JOIN products p ON p.id = wi.product_id
      JOIN warehouses w ON w.id = wi.warehouse_id
      WHERE wi.quantity <= wi.min_quantity $storeFilter
      ORDER BY wi.quantity ASC
    ''');
    return rows.map(_mapInventory).toList();
  }

  Future<void> updateInventoryQuantity(int warehouseId, int productId, int quantity) async {
    final db = await database;
    await db.update('warehouse_inventory', {'quantity': quantity, 'updated_at': DateTime.now().toIso8601String()},
        where: 'warehouse_id = ? AND product_id = ?', whereArgs: [warehouseId, productId]);
  }

  // ─── STOCK TRANSFER QUERIES ───────────────────────────────────────────────
  Future<List<StockTransferModel>> getAllStockTransfers({String? status}) async {
    final db = await database;
    final where = status != null ? "WHERE st.status = '$status'" : '';
    final rows = await db.rawQuery('''
      SELECT st.*,
        fw.name as from_warehouse_name, tw.name as to_warehouse_name,
        ru.full_name as requested_by_name, au.full_name as approved_by_name
      FROM stock_transfers st
      LEFT JOIN warehouses fw ON fw.id = st.from_warehouse_id
      LEFT JOIN warehouses tw ON tw.id = st.to_warehouse_id
      LEFT JOIN users ru ON ru.id = st.requested_by
      LEFT JOIN users au ON au.id = st.approved_by
      $where ORDER BY st.created_at DESC
    ''');
    final transfers = rows.map(_mapTransfer).toList();
    for (final t in transfers) {
      final itemRows = await db.rawQuery('''
        SELECT ti.*, p.name as product_name, p.sku as product_sku
        FROM stock_transfer_items ti JOIN products p ON p.id = ti.product_id
        WHERE ti.transfer_id = ?
      ''', [t.id]);
      t.items = itemRows.map(_mapTransferItem).toList();
    }
    return transfers;
  }

  Future<int> insertStockTransfer(StockTransferModel t) async {
    final db = await database;
    final id = await db.insert('stock_transfers', {
      'from_warehouse_id': t.fromWarehouseId, 'to_warehouse_id': t.toWarehouseId,
      'requested_by': t.requestedBy, 'status': t.status, 'note': t.note,
      'created_at': t.createdAt.toIso8601String(),
    });
    for (final item in t.items) {
      await db.insert('stock_transfer_items', {
        'transfer_id': id, 'product_id': item.productId,
        'estimate_quantity': item.estimateQuantity, 'actual_quantity': item.actualQuantity,
      });
    }
    return id;
  }

  Future<void> updateTransferStatus(int transferId, String status, {int? approvedBy}) async {
    final db = await database;
    final data = <String, dynamic>{'status': status};
    if (approvedBy != null) data['approved_by'] = approvedBy;
    if (status == 'received') data['received_at'] = DateTime.now().toIso8601String();
    await db.update('stock_transfers', data, where: 'id = ?', whereArgs: [transferId]);
  }

  /// Lấy danh sách phiếu chuyển kho theo kho nhận
  Future<List<StockTransferModel>> getTransfersByToWarehouse(int toWarehouseId, {String? status}) async {
    final db = await database;
    final statusFilter = status != null ? "AND st.status = '$status'" : '';
    final rows = await db.rawQuery('''
      SELECT st.*,
        fw.name as from_warehouse_name, tw.name as to_warehouse_name,
        ru.full_name as requested_by_name, au.full_name as approved_by_name
      FROM stock_transfers st
      LEFT JOIN warehouses fw ON fw.id = st.from_warehouse_id
      LEFT JOIN warehouses tw ON tw.id = st.to_warehouse_id
      LEFT JOIN users ru ON ru.id = st.requested_by
      LEFT JOIN users au ON au.id = st.approved_by
      WHERE st.to_warehouse_id = ? $statusFilter
      ORDER BY st.created_at DESC
    ''', [toWarehouseId]);
    final transfers = rows.map(_mapTransfer).toList();
    for (final t in transfers) {
      final itemRows = await db.rawQuery('''
        SELECT ti.*, p.name as product_name, p.sku as product_sku
        FROM stock_transfer_items ti JOIN products p ON p.id = ti.product_id
        WHERE ti.transfer_id = ?
      ''', [t.id]);
      t.items = itemRows.map(_mapTransferItem).toList();
    }
    return transfers;
  }

  /// Xác nhận nhận hàng: cập nhật actual_qty, tồn kho kho nhận, đổi status = 'received'
  Future<void> receiveTransfer({
    required int transferId,
    required int toWarehouseId,
    required int receivedBy,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final item in items) {
        await txn.update(
          'stock_transfer_items',
          {'actual_quantity': item['actualQty']!},
          where: 'id = ?', whereArgs: [item['itemId']!],
        );
        final invRows = await txn.query(
          'warehouse_inventory',
          columns: ['id', 'quantity'],
          where: 'warehouse_id = ? AND product_id = ?',
          whereArgs: [toWarehouseId, item['productId']!],
        );
        if (invRows.isNotEmpty) {
          final currentQty = invRows.first['quantity'] as int;
          final updateData = <String, Object?>{
             'quantity': currentQty + (item['actualQty'] as int), 
             'updated_at': now
          };
          if (item['expiryDate'] != null) {
             updateData['expiry_date'] = item['expiryDate'];
          }
          await txn.update(
            'warehouse_inventory',
            updateData,
            where: 'id = ?', whereArgs: [invRows.first['id']],
          );
        } else {
          await txn.insert('warehouse_inventory', {
            'warehouse_id': toWarehouseId, 'product_id': item['productId']!,
            'quantity': item['actualQty']!, 'min_quantity': 10, 
            'expiry_date': item['expiryDate'], 'updated_at': now,
          });
        }
      }
      await txn.update(
        'stock_transfers',
        {'status': 'received', 'approved_by': receivedBy, 'received_at': now},
        where: 'id = ?', whereArgs: [transferId],
      );
    });
  }

  // ─── SALES ORDER QUERIES ──────────────────────────────────────────────────

  Future<List<SalesOrderModel>> getSalesOrders({
    int? storeId, DateTime? from, DateTime? to, String? paymentStatus,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (storeId != null) { conditions.add('so.store_id = ?'); args.add(storeId); }
    if (from != null)    { conditions.add('so.order_date >= ?'); args.add(from.toIso8601String()); }
    if (to != null)      { conditions.add('so.order_date <= ?'); args.add(to.toIso8601String()); }
    if (paymentStatus != null) { conditions.add('so.payment_status = ?'); args.add(paymentStatus); }
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final rows = await db.rawQuery('''
      SELECT so.*, u.full_name as staff_name, s.name as store_name
      FROM sales_orders so
      LEFT JOIN users u ON u.id = so.staff_user_id
      LEFT JOIN stores s ON s.id = so.store_id
      $where ORDER BY so.order_date DESC
    ''', args);
    final orders = rows.map(_mapOrder).toList();
    for (final o in orders) {
      final itemRows = await db.rawQuery('''
        SELECT soi.*, p.name as product_name
        FROM sales_order_items soi JOIN products p ON p.id = soi.product_id
        WHERE soi.sales_order_id = ?
      ''', [o.id]);
      o.items = itemRows.map(_mapOrderItem).toList();
      final payRows = await db.query('payments', where: 'sales_order_id = ?', whereArgs: [o.id]);
      o.payments = payRows.map(_mapPayment).toList();
    }
    return orders;
  }

  Future<int> insertSalesOrder(SalesOrderModel order) async {
    final db = await database;
    final id = await db.insert('sales_orders', {
      'order_no': order.orderNo, 'store_id': order.storeId, 'staff_user_id': order.staffUserId,
      'order_date': order.orderDate.toIso8601String(),
      'total_amount': order.totalAmount, 'discount_amount': order.discountAmount,
      'final_amount': order.finalAmount, 'payment_status': order.paymentStatus,
      'note': order.note, 'created_at': order.createdAt.toIso8601String(),
    });
    for (final item in order.items) {
      await db.insert('sales_order_items', {
        'sales_order_id': id, 'product_id': item.productId,
        'quantity': item.quantity, 'unit_price': item.unitPrice, 'line_total': item.lineTotal,
      });
    }
    for (final pay in order.payments) {
      await db.insert('payments', {
        'sales_order_id': id, 'payment_method': pay.paymentMethod,
        'amount': pay.amount, 'paid_at': pay.paidAt.toIso8601String(),
      });
    }
    return id;
  }

  // ─── REVENUE AGGREGATION ──────────────────────────────────────────────────
  Future<double> getTotalRevenue({int? storeId, required DateTime from, required DateTime to}) async {
    final db = await database;
    final storeFilter = storeId != null ? "AND so.store_id = $storeId" : '';
    final rows = await db.rawQuery('''
      SELECT SUM(final_amount) as total FROM sales_orders so
      WHERE order_date BETWEEN ? AND ? $storeFilter AND payment_status = 'paid'
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return ((rows.first['total'] as num?) ?? 0).toDouble();
  }

  Future<int> getTotalOrderCount({int? storeId, required DateTime from, required DateTime to}) async {
    final db = await database;
    final storeFilter = storeId != null ? "AND store_id = $storeId" : '';
    final rows = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM sales_orders
      WHERE order_date BETWEEN ? AND ? $storeFilter
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return (rows.first['cnt'] as int?) ?? 0;
  }

  Future<List<ChartEntry>> getRevenueChartData(int? storeId, PeriodFilter period) async {
    final db = await database;
    final now = DateTime.now();
    final storeFilter = storeId != null ? 'AND store_id = $storeId' : '';
    String groupFormat;
    DateTime from;
    if (period == PeriodFilter.day) {
      groupFormat = "%H";
      from = DateTime(now.year, now.month, now.day);
    } else if (period == PeriodFilter.week) {
      groupFormat = "%w";
      from = now.subtract(const Duration(days: 6));
    } else {
      groupFormat = "%d";
      from = DateTime(now.year, now.month, 1);
    }
    final rows = await db.rawQuery('''
      SELECT strftime('$groupFormat', order_date) as label, SUM(final_amount) as total
      FROM sales_orders
      WHERE order_date >= ? $storeFilter AND payment_status = 'paid'
      GROUP BY label ORDER BY label ASC
    ''', [from.toIso8601String()]);
    return rows.map((r) => ChartEntry(
      label: r['label'] as String,
      value: ((r['total'] as num?) ?? 0).toDouble(),
    )).toList();
  }

  Future<List<ChartEntry>> getRevenueChartDataByDateRange(int? storeId, DateTime from, DateTime to) async {
    final db = await database;
    final storeFilter = storeId != null ? 'AND store_id = $storeId' : '';
    
    // Determine group format based on duration
    final diff = to.difference(from).inDays;
    String groupFormat;
    if (diff <= 1) {
      groupFormat = "%H"; // Group by hour
    } else {
      groupFormat = "%Y-%m-%d"; // Group by date
    }
    
    final rows = await db.rawQuery('''
      SELECT strftime('$groupFormat', order_date) as label, SUM(final_amount) as total
      FROM sales_orders
      WHERE order_date >= ? AND order_date <= ? $storeFilter AND payment_status = 'paid'
      GROUP BY label ORDER BY label ASC
    ''', [from.toIso8601String(), to.toIso8601String()]);
    
    return rows.map((r) => ChartEntry(
      label: r['label'] as String,
      value: ((r['total'] as num?) ?? 0).toDouble(),
    )).toList();
  }

  Future<List<ProductSaleModel>> getTopProducts({int? storeId, DateTime? from, DateTime? to, int limit = 5}) async {
    final db = await database;
    final conditions = <String>['so.payment_status = \'paid\''];
    final args = <dynamic>[];
    
    if (storeId != null) {
      conditions.add('so.store_id = ?');
      args.add(storeId);
    }
    if (from != null) {
      conditions.add('so.order_date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('so.order_date <= ?');
      args.add(to.toIso8601String());
    }
    
    final where = 'WHERE ${conditions.join(' AND ')}';
    
    final rows = await db.rawQuery('''
      SELECT p.id, p.name, SUM(soi.quantity) as qty, SUM(soi.line_total) as revenue
      FROM sales_order_items soi
      JOIN products p ON p.id = soi.product_id
      JOIN sales_orders so ON so.id = soi.sales_order_id
      $where
      GROUP BY p.id ORDER BY qty DESC LIMIT $limit
    ''', args);
    
    return rows.map((r) => ProductSaleModel(
      productId: r['id'] as int,
      productName: r['name'] as String,
      quantity: (r['qty'] as int?) ?? 0,
      totalRevenue: ((r['revenue'] as num?) ?? 0).toDouble(),
    )).toList();
  }

  // ─── SHIFT QUERIES ────────────────────────────────────────────────────────
  Future<List<WorkShiftModel>> getAllShifts() async {
    final db = await database;
    final rows = await db.query('work_shifts', where: "status = 'active'", orderBy: 'start_time ASC');
    return rows.map(_mapShift).toList();
  }

  Future<List<ShiftAssignmentModel>> getShiftAssignments({int? userId, int? storeId, DateTime? fromDate, DateTime? toDate}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (userId != null) { conditions.add('sa.user_id = ?'); args.add(userId); }
    if (fromDate != null) {
      conditions.add('sa.work_date >= ?');
      args.add('${fromDate.year}-${fromDate.month.toString().padLeft(2,'0')}-${fromDate.day.toString().padLeft(2,'0')}');
    }
    if (toDate != null) {
      conditions.add('sa.work_date <= ?');
      args.add('${toDate.year}-${toDate.month.toString().padLeft(2,'0')}-${toDate.day.toString().padLeft(2,'0')}');
    }
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final rows = await db.rawQuery('''
      SELECT sa.*, ws.name as shift_name, ws.start_time as shift_start, ws.end_time as shift_end,
             u.full_name as user_name, ab.full_name as assigned_by_name
      FROM shift_assignments sa
      JOIN work_shifts ws ON ws.id = sa.shift_id
      JOIN users u ON u.id = sa.user_id
      LEFT JOIN users ab ON ab.id = sa.assigned_by
      $where ORDER BY sa.work_date DESC, ws.start_time ASC
    ''', args);
    return rows.map(_mapShiftAssignment).toList();
  }

  Future<void> insertShiftAssignment(ShiftAssignmentModel a) async {
    final db = await database;
    await db.insert('shift_assignments', {
      'shift_id': a.shiftId, 'user_id': a.userId,
      'work_date': '${a.workDate.year}-${a.workDate.month.toString().padLeft(2,'0')}-${a.workDate.day.toString().padLeft(2,'0')}',
      'status': a.status, 'assigned_by': a.assignedBy, 'created_at': a.createdAt.toIso8601String(),
    });
  }

  Future<void> updateShiftAssignmentStatus(int id, String status) async {
    final db = await database;
    await db.update('shift_assignments', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteShiftAssignment(int id) async {
    final db = await database;
    await db.delete('shift_assignments', where: 'id = ?', whereArgs: [id]);
  }

  // ─── NOTIFICATION QUERIES ─────────────────────────────────────────────────
  Future<List<NotificationModel>> getNotifications({int? userId}) async {
    final db = await database;
    final where = userId != null ? 'WHERE n.target_user_id = $userId' : '';
    final rows = await db.rawQuery('''
      SELECT n.*, u.full_name as target_user_name
      FROM notifications n LEFT JOIN users u ON u.id = n.target_user_id
      $where ORDER BY n.created_at DESC LIMIT 100
    ''');
    return rows.map(_mapNotification).toList();
  }

  Future<void> markNotificationRead(int id) async {
    final db = await database;
    await db.update('notifications', {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Đánh dấu tất cả thông báo của [userId] là đã đọc.
  Future<void> markAllNotificationsRead(int userId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'target_user_id = ? AND is_read = 0',
      whereArgs: [userId],
    );
  }

  /// Đếm số thông báo chưa đọc của [userId].
  Future<int> getUnreadNotificationCount(int userId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM notifications WHERE target_user_id = ? AND is_read = 0',
      [userId],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  /// Chèn một notification mới, trả về id vừa tạo.
  Future<int> insertNotification({
    required String type,
    required String title,
    required String content,
    int? targetUserId,
    int? storeId,
    int? productId,
  }) async {
    final db = await database;
    return await db.insert('notifications', {
      'type': type,
      'title': title,
      'content': content,
      'target_user_id': targetUserId,
      'store_id': storeId,
      'product_id': productId,
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Kiểm tra hàng sắp hết và tạo notification nếu chưa có (anti-spam).
  ///
  /// Anti-spam: bỏ qua nếu đã tồn tại notification [type='low_stock',
  /// is_read=0] cho cùng product_id + store_id.
  Future<int> checkAndInsertLowStockNotifications({int? storeId}) async {
    final db     = await database;
    final now    = DateTime.now();
    int created  = 0;

    // Lấy danh sách hàng sắp hết (quantity <= min_quantity)
    final lowItems = await getLowStockItems(storeId: storeId);
    if (lowItems.isEmpty) return 0;

    for (final item in lowItems) {
      // Lấy store_id từ warehouse
      final whRows = await db.query(
        'warehouses', columns: ['store_id'], where: 'id = ?', whereArgs: [item.warehouseId],
      );
      if (whRows.isEmpty) continue;
      final sId = whRows.first['store_id'] as int;

      // Anti-spam — đã có notification chưa đọc cho cùng product+store chưa?
      final exists = await db.rawQuery('''
        SELECT 1 FROM notifications
        WHERE type = 'low_stock'
          AND product_id = ?
          AND store_id   = ?
          AND is_read    = 0
        LIMIT 1
      ''', [item.productId, sId]);
      if (exists.isNotEmpty) continue;

      // Lấy tên cửa hàng
      final stRows = await db.query(
        'stores', columns: ['name'], where: 'id = ?', whereArgs: [sId],
      );
      final storeName = stRows.isNotEmpty ? stRows.first['name'] as String : 'Cửa hàng #$sId';
      final productName = item.productName ?? 'Sản phẩm #${item.productId}';

      final title   = 'Sắp hết hàng: $productName';
      final content = '$productName tại $storeName sắp hết hàng. Số lượng còn lại: ${item.quantity}';

      // Người nhận 1: storeManager của store đó
      final managerRows = await db.query(
        'users',
        columns: ['id'],
        where: "role = 'storeManager' AND store_id = ? AND status = 'active'",
        whereArgs: [sId],
      );

      // Người nhận 2: tất cả inventoryChecker
      final checkerRows = await db.query(
        'users',
        columns: ['id'],
        where: "role = 'inventoryChecker' AND status = 'active'",
      );

      final recipients = [
        ...managerRows.map((r) => r['id'] as int),
        ...checkerRows.map((r) => r['id'] as int),
      ].toSet(); // loại trùng nếu có

      for (final uid in recipients) {
        await db.insert('notifications', {
          'type':           'low_stock',
          'title':          title,
          'content':        content,
          'target_user_id': uid,
          'store_id':       sId,
          'product_id':     item.productId,
          'is_read':        0,
          'created_at':     now.toIso8601String(),
        });
        created++;
      }
    }
    return created;
  }

  // ─── INVENTORY LOG QUERIES ────────────────────────────────────────────────
  Future<List<InventoryLogModel>> getInventoryLogs({int? productId, int? warehouseId, int limit = 50}) async {
    final db = await database;
    final conditions = <String>[];
    if (productId != null) conditions.add('il.product_id = $productId');
    if (warehouseId != null) conditions.add('il.source_id = $warehouseId');
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final rows = await db.rawQuery('''
      SELECT il.*, p.name as product_name, u.full_name as created_by_name
      FROM inventory_logs il
      JOIN products p ON p.id = il.product_id
      LEFT JOIN users u ON u.id = il.created_by
      $where ORDER BY il.created_at DESC LIMIT $limit
    ''');
    return rows.map(_mapInventoryLog).toList();
  }

  // ─── MAPPERS ──────────────────────────────────────────────────────────────
  UserModel _mapUser(Map<String, dynamic> r) => UserModel(
    id: r['id'] as int,
    username: r['username'] as String,
    passwordHash: r['password_hash'] as String,
    fullName: r['full_name'] as String,
    phone: r['phone'] as String?,
    email: r['email'] as String?,
    role: _roleFromString(r['role'] as String),
    storeId: r['store_id'] as int?,
    startDate: r['start_date'] != null ? DateTime.tryParse(r['start_date'] as String) : null,
    endDate: r['end_date'] != null ? DateTime.tryParse(r['end_date'] as String) : null,
    status: r['status'] as String? ?? 'active',
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String),
  );

  Map<String, dynamic> _userToMap(UserModel u) => {
    'username': u.username, 'password_hash': u.passwordHash, 'full_name': u.fullName,
    'phone': u.phone, 'email': u.email, 'role': _roleToString(u.role),
    'store_id': u.storeId, 'start_date': u.startDate?.toIso8601String(),
    'end_date': u.endDate?.toIso8601String(), 'status': u.status,
    'created_at': u.createdAt.toIso8601String(), 'updated_at': u.updatedAt.toIso8601String(),
  };

  StoreModel _mapStore(Map<String, dynamic> r) => StoreModel(
    id: r['id'] as int, code: r['code'] as String, name: r['name'] as String,
    address: r['address'] as String?, phone: r['phone'] as String?,
    status: r['status'] as String? ?? 'active',
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String),
  );

  WarehouseModel _mapWarehouse(Map<String, dynamic> r) => WarehouseModel(
    id: r['id'] as int, code: r['code'] as String, name: r['name'] as String,
    type: r['type'] as String, storeId: r['store_id'] as int,
    address: r['address'] as String?, phone: r['phone'] as String?,
    managerUserId: r['manager_user_id'] as int?,
    status: r['status'] as String? ?? 'active',
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String),
    storeName: r['store_name'] as String?, managerName: r['manager_name'] as String?,
  );

  CategoryModel _mapCategory(Map<String, dynamic> r) => CategoryModel(
    id: r['id'] as int, name: r['name'] as String, description: r['description'] as String?,
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String),
  );

  ProductModel _mapProduct(Map<String, dynamic> r) => ProductModel(
    id: r['id'] as int, sku: r['sku'] as String, barcode: r['barcode'] as String?,
    name: r['name'] as String, categoryId: r['category_id'] as int,
    unit: r['unit'] as String? ?? 'cup',
    costPrice: (r['cost_price'] as num).toDouble(),
    sellingPrice: (r['selling_price'] as num).toDouble(),
    status: r['status'] as String? ?? 'active',
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String),
    categoryName: r['category_name'] as String?,
    emoji: r['emoji'] as String? ?? '🧋',
  );

  WarehouseInventoryModel _mapInventory(Map<String, dynamic> r) => WarehouseInventoryModel(
    id: r['id'] as int, warehouseId: r['warehouse_id'] as int, productId: r['product_id'] as int,
    quantity: r['quantity'] as int, minQuantity: r['min_quantity'] as int,
    expiryDate: r['expiry_date'] != null ? DateTime.parse(r['expiry_date'] as String) : null,
    updatedAt: DateTime.parse(r['updated_at'] as String),
    productName: r['product_name'] as String?, warehouseName: r['warehouse_name'] as String?,
    productSku: r['product_sku'] as String?,
  );

  StockTransferModel _mapTransfer(Map<String, dynamic> r) => StockTransferModel(
    id: r['id'] as int, fromWarehouseId: r['from_warehouse_id'] as int,
    toWarehouseId: r['to_warehouse_id'] as int, requestedBy: r['requested_by'] as int,
    approvedBy: r['approved_by'] as int?, status: r['status'] as String,
    note: r['note'] as String?,
    createdAt: DateTime.parse(r['created_at'] as String),
    receivedAt: r['received_at'] != null ? DateTime.tryParse(r['received_at'] as String) : null,
    fromWarehouseName: r['from_warehouse_name'] as String?,
    toWarehouseName: r['to_warehouse_name'] as String?,
    requestedByName: r['requested_by_name'] as String?,
    approvedByName: r['approved_by_name'] as String?,
  );

  StockTransferItemModel _mapTransferItem(Map<String, dynamic> r) => StockTransferItemModel(
    id: r['id'] as int, transferId: r['transfer_id'] as int, productId: r['product_id'] as int,
    estimateQuantity: r['estimate_quantity'] as int, actualQuantity: r['actual_quantity'] as int,
    productName: r['product_name'] as String?, productSku: r['product_sku'] as String?,
  );

  SalesOrderModel _mapOrder(Map<String, dynamic> r) => SalesOrderModel(
    id: r['id'] as int, orderNo: r['order_no'] as String,
    storeId: r['store_id'] as int, staffUserId: r['staff_user_id'] as int,
    orderDate: DateTime.parse(r['order_date'] as String),
    totalAmount: (r['total_amount'] as num).toDouble(),
    discountAmount: (r['discount_amount'] as num? ?? 0).toDouble(),
    finalAmount: (r['final_amount'] as num).toDouble(),
    paymentStatus: r['payment_status'] as String? ?? 'paid',
    note: r['note'] as String?,
    createdAt: DateTime.parse(r['created_at'] as String),
    staffName: r['staff_name'] as String?, storeName: r['store_name'] as String?,
  );

  SalesOrderItemModel _mapOrderItem(Map<String, dynamic> r) => SalesOrderItemModel(
    id: r['id'] as int, salesOrderId: r['sales_order_id'] as int, productId: r['product_id'] as int,
    quantity: r['quantity'] as int, unitPrice: (r['unit_price'] as num).toDouble(),
    lineTotal: (r['line_total'] as num).toDouble(), productName: r['product_name'] as String?,
  );

  PaymentModel _mapPayment(Map<String, dynamic> r) => PaymentModel(
    id: r['id'] as int, salesOrderId: r['sales_order_id'] as int,
    paymentMethod: r['payment_method'] as String, amount: (r['amount'] as num).toDouble(),
    paidAt: DateTime.parse(r['paid_at'] as String),
  );

  WorkShiftModel _mapShift(Map<String, dynamic> r) => WorkShiftModel(
    id: r['id'] as int, name: r['name'] as String,
    startTime: r['start_time'] as String, endTime: r['end_time'] as String,
    status: r['status'] as String? ?? 'active',
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String),
  );

  ShiftAssignmentModel _mapShiftAssignment(Map<String, dynamic> r) => ShiftAssignmentModel(
    id: r['id'] as int, shiftId: r['shift_id'] as int, userId: r['user_id'] as int,
    workDate: DateTime.parse(r['work_date'] as String),
    status: r['status'] as String? ?? 'scheduled', assignedBy: r['assigned_by'] as int,
    createdAt: DateTime.parse(r['created_at'] as String),
    shiftName: r['shift_name'] as String?, shiftStartTime: r['shift_start'] as String?,
    shiftEndTime: r['shift_end'] as String?, userName: r['user_name'] as String?,
    assignedByName: r['assigned_by_name'] as String?,
  );

  NotificationModel _mapNotification(Map<String, dynamic> r) => NotificationModel(
    id: r['id'] as int, type: r['type'] as String, title: r['title'] as String,
    content: r['content'] as String, targetUserId: r['target_user_id'] as int?,
    storeId: r['store_id'] as int?, productId: r['product_id'] as int?,
    isRead: (r['is_read'] as int) == 1,
    createdAt: DateTime.parse(r['created_at'] as String),
    targetUserName: r['target_user_name'] as String?,
  );

  InventoryLogModel _mapInventoryLog(Map<String, dynamic> r) => InventoryLogModel(
    id: r['id'] as int, sourceId: r['source_id'] as int?, productId: r['product_id'] as int,
    changeType: r['change_type'] as String,
    quantityBefore: r['quantity_before'] as int, quantityChange: r['quantity_change'] as int,
    quantityAfter: r['quantity_after'] as int, referenceType: r['reference_type'] as String,
    referenceId: r['reference_id'] as int?, orderId: r['order_id'] as int?,
    createdBy: r['created_by'] as int?, createdAt: DateTime.parse(r['created_at'] as String),
    productName: r['product_name'] as String?, createdByName: r['created_by_name'] as String?,
  );

  // ─── ENUM HELPERS ─────────────────────────────────────────────────────────
  UserRole _roleFromString(String s) {
    switch (s) {
      case 'ceoAdmin':         return UserRole.ceoAdmin;
      case 'itAdmin':          return UserRole.itAdmin;
      case 'storeManager':     return UserRole.storeManager;
      case 'inventoryChecker': return UserRole.inventoryChecker;
      default:                 return UserRole.staff;
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

class ChartEntry {
  final String label;
  final double value;
  const ChartEntry({required this.label, required this.value});
}
