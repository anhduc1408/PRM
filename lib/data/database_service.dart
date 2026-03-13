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
    return openDatabase(path, version: 2, onCreate: (db, v) async {
      await _createTables(db);
      await _seedData(db);
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
    await db.insert('stores', {'code': 'STR001', 'name': 'Mixue Quận 1', 'address': '123 Nguyễn Huệ, Q.1', 'phone': '028-1234-5678', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('stores', {'code': 'STR002', 'name': 'Mixue Quận 3', 'address': '456 Võ Văn Tần, Q.3', 'phone': '028-2345-6789', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('stores', {'code': 'STR003', 'name': 'Mixue Bình Thạnh', 'address': '789 Đinh Bộ Lĩnh, BTh', 'phone': '028-3456-7890', 'status': 'active', 'created_at': now, 'updated_at': now});

    // Users
    await db.insert('users', {'username': 'ceo', 'password_hash': '123456', 'full_name': 'CEO Admin', 'email': 'ceo@mixue.vn', 'role': 'ceoAdmin', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('users', {'username': 'it', 'password_hash': '123456', 'full_name': 'IT Admin', 'email': 'it@mixue.vn', 'role': 'itAdmin', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('users', {'username': 'staff1', 'password_hash': '123456', 'full_name': 'Nguyễn Văn An', 'email': 'staff1@mixue.vn', 'role': 'staff', 'store_id': 1, 'phone': '0901234567', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('users', {'username': 'staff2', 'password_hash': '123456', 'full_name': 'Trần Thị Bình', 'email': 'staff2@mixue.vn', 'role': 'staff', 'store_id': 2, 'phone': '0912345678', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('users', {'username': 'manager1', 'password_hash': '123456', 'full_name': 'Lê Quản Lý', 'email': 'manager1@mixue.vn', 'role': 'storeManager', 'store_id': 1, 'phone': '0923456789', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('users', {'username': 'checker1', 'password_hash': '123456', 'full_name': 'Phạm Kiểm Kho', 'email': 'checker1@mixue.vn', 'role': 'inventoryChecker', 'store_id': 1, 'phone': '0934567890', 'status': 'active', 'created_at': now, 'updated_at': now});

    // Warehouses
    await db.insert('warehouses', {'code': 'WH001', 'name': 'Kho Tổng', 'type': 'main', 'store_id': 1, 'address': '1 Trung Tâm, Q.1', 'manager_user_id': 5, 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('warehouses', {'code': 'WH002', 'name': 'Kho Quận 1', 'type': 'store', 'store_id': 1, 'manager_user_id': 5, 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('warehouses', {'code': 'WH003', 'name': 'Kho Quận 3', 'type': 'store', 'store_id': 2, 'status': 'active', 'created_at': now, 'updated_at': now});

    // Categories
    await db.insert('categories', {'name': 'Kem', 'description': 'Các loại kem', 'created_at': now, 'updated_at': now});
    await db.insert('categories', {'name': 'Trà', 'description': 'Trà sữa, trà hoa quả', 'created_at': now, 'updated_at': now});
    await db.insert('categories', {'name': 'Cà phê', 'description': 'Cà phê các loại', 'created_at': now, 'updated_at': now});
    await db.insert('categories', {'name': 'Tráng miệng', 'description': 'Bánh, chè', 'created_at': now, 'updated_at': now});
    await db.insert('categories', {'name': 'Khác', 'description': 'Sản phẩm khác', 'created_at': now, 'updated_at': now});

    // Products
    final products = [
      {'sku': 'ICE001', 'name': 'Kem Que Mix', 'category_id': 1, 'unit': 'cây', 'cost_price': 5000.0, 'selling_price': 10000.0, 'emoji': '🍦'},
      {'sku': 'ICE002', 'name': 'Kem Bơ Sữa', 'category_id': 1, 'unit': 'cây', 'cost_price': 8000.0, 'selling_price': 15000.0, 'emoji': '🍨'},
      {'sku': 'ICE003', 'name': 'Kem Socola', 'category_id': 1, 'unit': 'cây', 'cost_price': 10000.0, 'selling_price': 20000.0, 'emoji': '🍫'},
      {'sku': 'TEA001', 'name': 'Trà Sữa Original', 'category_id': 2, 'unit': 'ly', 'cost_price': 15000.0, 'selling_price': 35000.0, 'emoji': '🧋'},
      {'sku': 'TEA002', 'name': 'Trà Đào Cam Sả', 'category_id': 2, 'unit': 'ly', 'cost_price': 12000.0, 'selling_price': 29000.0, 'emoji': '🍑'},
      {'sku': 'TEA003', 'name': 'Trà Xanh Matcha', 'category_id': 2, 'unit': 'ly', 'cost_price': 18000.0, 'selling_price': 39000.0, 'emoji': '🍵'},
      {'sku': 'COF001', 'name': 'Cà Phê Sữa', 'category_id': 3, 'unit': 'ly', 'cost_price': 10000.0, 'selling_price': 25000.0, 'emoji': '☕'},
      {'sku': 'COF002', 'name': 'Cà Phê Đen', 'category_id': 3, 'unit': 'ly', 'cost_price': 8000.0, 'selling_price': 20000.0, 'emoji': '🍶'},
      {'sku': 'DST001', 'name': 'Chè Ba Màu', 'category_id': 4, 'unit': 'ly', 'cost_price': 12000.0, 'selling_price': 28000.0, 'emoji': '🍮'},
      {'sku': 'DST002', 'name': 'Bánh Flan', 'category_id': 4, 'unit': 'cái', 'cost_price': 8000.0, 'selling_price': 18000.0, 'emoji': '🍯'},
    ];
    for (final prod in products) {
      await db.insert('products', {...prod, 'status': 'active', 'created_at': now, 'updated_at': now});
    }

    // Warehouse Inventory
    for (int wh = 1; wh <= 3; wh++) {
      for (int prod = 1; prod <= 10; prod++) {
        await db.insert('warehouse_inventory', {
          'warehouse_id': wh, 'product_id': prod,
          'quantity': rng.nextInt(200) + 50, 'min_quantity': 20, 'updated_at': now,
        });
      }
    }

    // Work Shifts
    await db.insert('work_shifts', {'name': 'Ca Sáng', 'start_time': '06:00', 'end_time': '14:00', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('work_shifts', {'name': 'Ca Chiều', 'start_time': '14:00', 'end_time': '22:00', 'status': 'active', 'created_at': now, 'updated_at': now});
    await db.insert('work_shifts', {'name': 'Ca Tối', 'start_time': '22:00', 'end_time': '06:00', 'status': 'active', 'created_at': now, 'updated_at': now});

    // Shift Assignments (last 14 days)
    for (int day = -7; day <= 7; day++) {
      final date = DateTime.now().add(Duration(days: day));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
      for (final userId in [3, 4, 5]) {
        await db.insert('shift_assignments', {
          'shift_id': rng.nextInt(3) + 1, 'user_id': userId,
          'work_date': dateStr, 'status': day < 0 ? 'completed' : 'scheduled',
          'assigned_by': 2, 'created_at': now,
        });
      }
    }

    // Sales Orders (last 30 days)
    int orderCounter = 1;
    for (int day = -29; day <= 0; day++) {
      final date = DateTime.now().add(Duration(days: day));
      final ordersPerDay = rng.nextInt(8) + 3;
      for (int i = 0; i < ordersPerDay; i++) {
        final storeId = rng.nextInt(3) + 1;
        final prodCount = rng.nextInt(3) + 1;
        double total = 0;
        final orderNo = 'ORD${orderCounter.toString().padLeft(6,'0')}';
        final orderId = await db.insert('sales_orders', {
          'order_no': orderNo, 'store_id': storeId, 'staff_user_id': storeId == 1 ? 3 : 4,
          'order_date': date.toIso8601String(), 'total_amount': 0,
          'discount_amount': 0, 'final_amount': 0, 'payment_status': 'paid', 'created_at': date.toIso8601String(),
        });
        for (int j = 0; j < prodCount; j++) {
          final prodId = rng.nextInt(10) + 1;
          final qty = rng.nextInt(3) + 1;
          final price = products[prodId - 1]['selling_price'] as double;
          final lineTotal = price * qty;
          total += lineTotal;
          await db.insert('sales_order_items', {
            'sales_order_id': orderId, 'product_id': prodId,
            'quantity': qty, 'unit_price': price, 'line_total': lineTotal,
          });
        }
        await db.update('sales_orders', {'total_amount': total, 'final_amount': total}, where: 'id = ?', whereArgs: [orderId]);
        final method = rng.nextBool() ? 'cash' : 'transfer';
        await db.insert('payments', {
          'sales_order_id': orderId, 'payment_method': method, 'amount': total, 'paid_at': date.toIso8601String(),
        });
        orderCounter++;
      }
    }
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

  Future<List<ProductSaleModel>> getTopProducts({int? storeId, int limit = 5}) async {
    final db = await database;
    final storeFilter = storeId != null ? 'AND so.store_id = $storeId' : '';
    final rows = await db.rawQuery('''
      SELECT p.id, p.name, SUM(soi.quantity) as qty, SUM(soi.line_total) as revenue
      FROM sales_order_items soi
      JOIN products p ON p.id = soi.product_id
      JOIN sales_orders so ON so.id = soi.sales_order_id
      WHERE so.payment_status = 'paid' $storeFilter
      GROUP BY p.id ORDER BY qty DESC LIMIT $limit
    ''');
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

  // ─── NOTIFICATION QUERIES ─────────────────────────────────────────────────
  Future<List<NotificationModel>> getNotifications({int? userId}) async {
    final db = await database;
    final where = userId != null ? 'WHERE n.target_user_id = $userId' : '';
    final rows = await db.rawQuery('''
      SELECT n.*, u.full_name as target_user_name
      FROM notifications n LEFT JOIN users u ON u.id = n.target_user_id
      $where ORDER BY n.created_at DESC LIMIT 50
    ''');
    return rows.map(_mapNotification).toList();
  }

  Future<void> markNotificationRead(int id) async {
    final db = await database;
    await db.update('notifications', {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
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
