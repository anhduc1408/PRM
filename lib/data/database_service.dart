import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/user_model.dart';
import '../models/store_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/work_schedule_model.dart';
import '../core/constants/enums.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  // ─── OPEN / CREATE ────────────────────────────────────────────────────────
  Future<Database> _open() async {
    // Web: in-memory DB — bypasses sqflite_common_ffi_web WASM/worker issues in dev.
    // Data re-seeds every load (demo quality). Native uses file-based persistence.
    final String path;
    if (kIsWeb) {
      path = inMemoryDatabasePath; // ':memory:'
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, 'mixue_manager.db');
    }
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedData(db);
      },
    );
  }


  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stores (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        district TEXT NOT NULL,
        phone TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        opened_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        store_id TEXT,
        store_name TEXT,
        phone TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        category TEXT NOT NULL,
        emoji TEXT NOT NULL,
        description TEXT NOT NULL,
        store_id TEXT NOT NULL,
        is_available INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        staff_id TEXT NOT NULL,
        staff_name TEXT NOT NULL,
        store_id TEXT NOT NULL,
        shift TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS work_schedules (
        id TEXT PRIMARY KEY,
        staff_id TEXT NOT NULL,
        staff_name TEXT NOT NULL,
        date TEXT NOT NULL,
        shift TEXT NOT NULL,
        store_id TEXT NOT NULL
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_store ON orders(store_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_store ON products(store_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_schedules_staff ON work_schedules(staff_id)');
  }

  // ─── SEED DATA ────────────────────────────────────────────────────────────
  Future<void> _seedData(Database db) async {
    final stores = [
      {'id': 'store1', 'name': 'Mixue Nguyễn Trãi',   'address': '123 Nguyễn Trãi',   'district': 'Quận 1',          'phone': '028 3811 1111', 'is_active': 1, 'opened_at': '2022-05-01'},
      {'id': 'store2', 'name': 'Mixue Lê Văn Việt',   'address': '45 Lê Văn Việt',    'district': 'Quận 9',          'phone': '028 3811 2222', 'is_active': 1, 'opened_at': '2022-08-15'},
      {'id': 'store3', 'name': 'Mixue Hoàng Văn Thụ', 'address': '78 Hoàng Văn Thụ',  'district': 'Quận Phú Nhuận',  'phone': '028 3811 3333', 'is_active': 1, 'opened_at': '2023-01-10'},
      {'id': 'store4', 'name': 'Mixue Điện Biên Phủ', 'address': '200 Điện Biên Phủ', 'district': 'Quận Bình Thạnh', 'phone': '028 3811 4444', 'is_active': 1, 'opened_at': '2023-06-20'},
      {'id': 'store5', 'name': 'Mixue Phan Văn Trị',  'address': '55 Phan Văn Trị',   'district': 'Quận Gò Vấp',    'phone': '028 3811 5555', 'is_active': 0, 'opened_at': '2024-02-01'},
    ];
    for (final s in stores) { await db.insert('stores', s); }

    final users = [
      {'id': 'u1',  'name': 'Nguyễn Văn An',  'email': 'ceo@mixue.vn',    'password': '123456', 'role': 'ceoAdmin', 'store_id': null, 'store_name': null, 'phone': '0901 234 567'},
      {'id': 'u2',  'name': 'Trần Thị Bình',  'email': 'it@mixue.vn',     'password': '123456', 'role': 'itAdmin',  'store_id': null, 'store_name': null, 'phone': '0902 345 678'},
      {'id': 'u3',  'name': 'Lê Văn Cường',   'email': 'staff1@mixue.vn', 'password': '123456', 'role': 'staff',    'store_id': 'store1', 'store_name': 'Mixue Nguyễn Trãi',   'phone': '0903 456 789'},
      {'id': 'u4',  'name': 'Phạm Thị Dung',  'email': 'staff2@mixue.vn', 'password': '123456', 'role': 'staff',    'store_id': 'store1', 'store_name': 'Mixue Nguyễn Trãi',   'phone': '0904 567 890'},
      {'id': 'u5',  'name': 'Hoàng Văn Em',   'email': 'staff3@mixue.vn', 'password': '123456', 'role': 'staff',    'store_id': 'store2', 'store_name': 'Mixue Lê Văn Việt',   'phone': '0905 678 901'},
      {'id': 'u6',  'name': 'Vũ Thị Phương',  'email': 'staff4@mixue.vn', 'password': '123456', 'role': 'staff',    'store_id': 'store3', 'store_name': 'Mixue Hoàng Văn Thụ', 'phone': '0906 789 012'},
      {'id': 'u7',  'name': 'Đặng Văn Giang', 'email': 'staff5@mixue.vn', 'password': '123456', 'role': 'staff',    'store_id': 'store4', 'store_name': 'Mixue Điện Biên Phủ', 'phone': '0907 890 123'},
      {'id': 'u8',  'name': 'Bùi Thị Hoa',    'email': 'staff6@mixue.vn', 'password': '123456', 'role': 'staff',    'store_id': 'store2', 'store_name': 'Mixue Lê Văn Việt',   'phone': '0908 901 234'},
      {'id': 'u9',  'name': 'Mai Văn Ích',     'email': 'mgr1@mixue.vn',   'password': '123456', 'role': 'itAdmin',  'store_id': 'store3', 'store_name': 'Mixue Hoàng Văn Thụ', 'phone': '0909 012 345'},
      {'id': 'u10', 'name': 'Kiều Thị Kim',   'email': 'staff7@mixue.vn', 'password': '123456', 'role': 'staff',    'store_id': 'store5', 'store_name': 'Mixue Phan Văn Trị',  'phone': '0910 123 456'},
    ];
    for (final u in users) { await db.insert('users', u); }

    final productTemplates = [
      {'id': 'p1',  'name': 'Kem Óc Quế Vani',    'price': 10000.0, 'category': 'iceCream', 'emoji': '🍦', 'description': 'Kem mềm vị vani ngọt ngào'},
      {'id': 'p2',  'name': 'Kem Óc Quế Dâu',     'price': 10000.0, 'category': 'iceCream', 'emoji': '🍓', 'description': 'Kem mềm vị dâu tươi'},
      {'id': 'p3',  'name': 'Kem Nhúng Socola',    'price': 15000.0, 'category': 'iceCream', 'emoji': '🍫', 'description': 'Kem vani nhúng socola đen'},
      {'id': 'p4',  'name': 'Trà Sữa Trân Châu',   'price': 29000.0, 'category': 'tea',      'emoji': '🧋', 'description': 'Trà sữa đài loan trân châu đen'},
      {'id': 'p5',  'name': 'Trà Đào Cam Sả',      'price': 25000.0, 'category': 'tea',      'emoji': '🍑', 'description': 'Trà đào tươi cam sả mát lạnh'},
      {'id': 'p6',  'name': 'Trà Lục Trân Châu',   'price': 27000.0, 'category': 'tea',      'emoji': '🍵', 'description': 'Trà xanh lục trân châu trắng'},
      {'id': 'p7',  'name': 'Cà Phê Sữa Đá',       'price': 22000.0, 'category': 'coffee',   'emoji': '☕', 'description': 'Cà phê sữa đậm đà kiểu Việt'},
      {'id': 'p8',  'name': 'Cà Phê Muối',         'price': 25000.0, 'category': 'coffee',   'emoji': '🧂', 'description': 'Cà phê kết hợp kem muối béo'},
      {'id': 'p9',  'name': 'Chè Khúc Bạch',       'price': 32000.0, 'category': 'dessert',  'emoji': '🍮', 'description': 'Chè khúc bạch hạnh nhân mát lạnh'},
      {'id': 'p10', 'name': 'Hồng Trà Kem Tươi',   'price': 29000.0, 'category': 'tea',      'emoji': '🫖', 'description': 'Hồng trà đậm đà kem tươi béo'},
      {'id': 'p11', 'name': 'Sinh Tố Dâu',         'price': 35000.0, 'category': 'other',    'emoji': '🍓', 'description': 'Sinh tố dâu tươi thơm ngon'},
      {'id': 'p12', 'name': 'Nước Ép Cam',         'price': 30000.0, 'category': 'other',    'emoji': '🍊', 'description': 'Cam tươi nguyên chất ép lạnh'},
    ];

    final storeIds = ['store1', 'store2', 'store3', 'store4', 'store5'];
    for (final storeId in storeIds) {
      for (final t in productTemplates) {
        await db.insert('products', {
          'id': '${t['id']}_$storeId',
          'name': t['name'],
          'price': t['price'],
          'category': t['category'],
          'emoji': t['emoji'],
          'description': t['description'],
          'store_id': storeId,
          'is_available': 1,
        });
      }
    }

    await _seedOrders(db, users, productTemplates, storeIds);
    await _seedSchedules(db, users, storeIds);
  }

  Future<void> _seedOrders(Database db, List<Map<String, dynamic>> users,
      List<Map<String, dynamic>> products, List<String> storeIds) async {
    final rng = Random(42);
    final staffByStore = {
      'store1': [users[2], users[3]],
      'store2': [users[4], users[7]],
      'store3': [users[5]],
      'store4': [users[6]],
      'store5': [users[9]],
    };
    final now = DateTime.now();
    for (int day = 0; day < 30; day++) {
      final date = now.subtract(Duration(days: day));
      for (final storeId in storeIds) {
        final isActive = storeId != 'store5' || day <= 5;
        if (!isActive) continue;
        final staffList = staffByStore[storeId] ?? [users[2]];
        final ordersPerDay = rng.nextInt(25) + 10;
        for (int o = 0; o < ordersPerDay; o++) {
          final staff = staffList[rng.nextInt(staffList.length)];
          final hour = rng.nextInt(15) + 7;
          final minute = rng.nextInt(60);
          final orderTime = DateTime(date.year, date.month, date.day, hour, minute);
          final shiftStr = hour < 14 ? 'morning' : 'afternoon';
          final paymentStr = rng.nextBool() ? 'cash' : 'transfer';
          final orderId = 'ord_${storeId}_${day}_$o';
          await db.insert('orders', {
            'id': orderId,
            'created_at': orderTime.toIso8601String(),
            'payment_method': paymentStr,
            'staff_id': staff['id'],
            'staff_name': staff['name'],
            'store_id': storeId,
            'shift': shiftStr,
            'notes': null,
          });
          final numItems = rng.nextInt(3) + 1;
          for (int i = 0; i < numItems; i++) {
            final product = products[rng.nextInt(products.length)];
            final qty = rng.nextInt(3) + 1;
            await db.insert('order_items', {
              'order_id': orderId,
              'product_id': '${product['id']}_$storeId',
              'product_name': product['name'],
              'price': product['price'],
              'quantity': qty,
            });
          }
        }
      }
    }
  }

  Future<void> _seedSchedules(Database db, List<Map<String, dynamic>> users,
      List<String> storeIds) async {
    final rng = Random(77);
    final staffByStore = {
      'store1': [users[2], users[3]],
      'store2': [users[4], users[7]],
      'store3': [users[5]],
      'store4': [users[6]],
      'store5': [users[9]],
    };
    final shifts = ['morning', 'afternoon', 'evening'];
    final now = DateTime.now();
    int counter = 0;
    for (int day = -7; day <= 14; day++) {
      final date = now.add(Duration(days: day));
      for (final storeId in storeIds) {
        final staffList = staffByStore[storeId] ?? [users[2]];
        for (final staff in staffList) {
          if (rng.nextBool()) {
            final shift = shifts[rng.nextInt(shifts.length)];
            await db.insert('work_schedules', {
              'id': 'sch_${counter++}',
              'staff_id': staff['id'],
              'staff_name': staff['name'],
              'date': '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}',
              'shift': shift,
              'store_id': storeId,
            });
          }
        }
      }
    }
  }

  // ─── USER QUERIES ─────────────────────────────────────────────────────────
  Future<UserModel?> getUser(String email, String password) async {
    final db = await database;
    final rows = await db.query('users', where: 'email = ? AND password = ?',
        whereArgs: [email.trim(), password.trim()], limit: 1);
    if (rows.isEmpty) return null;
    return _mapUser(rows.first);
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final rows = await db.query('users', orderBy: 'name ASC');
    return rows.map(_mapUser).toList();
  }

  Future<void> insertUser(UserModel user) async {
    final db = await database;
    await db.insert('users', _userToMap(user), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateUserRole(String userId, String role, String? storeId, String? storeName) async {
    final db = await database;
    await db.update('users', {'role': role, 'store_id': storeId, 'store_name': storeName},
        where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> updateUser(UserModel user) async {
    final db = await database;
    await db.update('users', {
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'role': _roleToString(user.role),
      'store_id': user.storeId,
      'store_name': user.storeName,
    }, where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> resetPassword(String userId) async {
    final db = await database;
    await db.update('users', {'password': '123456'}, where: 'id = ?', whereArgs: [userId]);
  }


  Future<List<StoreModel>> getAllStores() async {
    final db = await database;
    final rows = await db.query('stores', orderBy: 'name ASC');
    return rows.map(_mapStore).toList();
  }

  Future<StoreModel?> getStore(String id) async {
    final db = await database;
    final rows = await db.query('stores', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _mapStore(rows.first);
  }

  // ─── PRODUCT QUERIES ──────────────────────────────────────────────────────
  Future<List<ProductModel>> getProductsForStore(String storeId) async {
    final db = await database;
    final rows = await db.query('products', where: 'store_id = ? AND is_available = 1',
        whereArgs: [storeId], orderBy: 'name ASC');
    return rows.map(_mapProduct).toList();
  }

  // ─── ORDER QUERIES ────────────────────────────────────────────────────────
  Future<List<OrderModel>> getOrders({String? storeId, DateTime? from, DateTime? to}) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (storeId != null) { where.add('o.store_id = ?'); args.add(storeId); }
    if (from != null)    { where.add('o.created_at >= ?'); args.add(from.toIso8601String()); }
    if (to != null)      { where.add('o.created_at <= ?'); args.add(to.toIso8601String()); }
    final whereClause = where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : '';

    final orderRows = await db.rawQuery('''
      SELECT o.id, o.created_at, o.payment_method, o.staff_id, o.staff_name,
             o.store_id, o.shift, o.notes
      FROM orders o $whereClause ORDER BY o.created_at DESC
    ''', args);
    if (orderRows.isEmpty) return [];

    final orderIds = orderRows.map((r) => "'${r['id']}'").join(',');
    final itemRows = await db.rawQuery('SELECT * FROM order_items WHERE order_id IN ($orderIds)');

    final itemsByOrder = <String, List<OrderItem>>{};
    for (final row in itemRows) {
      final orderId = row['order_id'] as String;
      itemsByOrder.putIfAbsent(orderId, () => []);
      itemsByOrder[orderId]!.add(OrderItem(
        productId: row['product_id'] as String,
        productName: row['product_name'] as String,
        price: (row['price'] as num).toDouble(),
        quantity: row['quantity'] as int,
      ));
    }

    return orderRows.map((row) {
      final id = row['id'] as String;
      return OrderModel(
        id: id,
        createdAt: DateTime.parse(row['created_at'] as String),
        paymentMethod: (row['payment_method'] as String) == 'cash' ? PaymentMethod.cash : PaymentMethod.transfer,
        staffId: row['staff_id'] as String,
        staffName: row['staff_name'] as String,
        storeId: row['store_id'] as String,
        shift: _shiftFromString(row['shift'] as String),
        notes: row['notes'] as String?,
        items: itemsByOrder[id] ?? [],
      );
    }).toList();
  }

  Future<void> insertOrder(OrderModel order) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('orders', {
        'id': order.id,
        'created_at': order.createdAt.toIso8601String(),
        'payment_method': order.paymentMethod == PaymentMethod.cash ? 'cash' : 'transfer',
        'staff_id': order.staffId,
        'staff_name': order.staffName,
        'store_id': order.storeId,
        'shift': _shiftToString(order.shift),
        'notes': order.notes,
      });
      for (final item in order.items) {
        await txn.insert('order_items', {
          'order_id': order.id,
          'product_id': item.productId,
          'product_name': item.productName,
          'price': item.price,
          'quantity': item.quantity,
        });
      }
    });
  }

  // ─── WORK SCHEDULE QUERIES ────────────────────────────────────────────────
  Future<List<WorkScheduleModel>> getSchedulesForStaff(String staffId) async {
    final db = await database;
    final rows = await db.query('work_schedules', where: 'staff_id = ?',
        whereArgs: [staffId], orderBy: 'date ASC');
    return rows.map((r) => WorkScheduleModel(
      id: r['id'] as String,
      staffId: r['staff_id'] as String,
      staffName: r['staff_name'] as String,
      date: DateTime.parse(r['date'] as String),
      shift: _shiftFromString(r['shift'] as String),
      storeId: r['store_id'] as String,
    )).toList();
  }

  // ─── AGGREGATION QUERIES ──────────────────────────────────────────────────
  Future<Map<String, double>> getRevenueGrouped({String? storeId, required DateTime from, required DateTime to, required String groupBy}) async {
    final db = await database;
    final storeFilter = storeId != null ? "AND o.store_id = '$storeId'" : '';
    final groupExpr = groupBy == 'hour' ? "strftime('%H', o.created_at)" : "strftime('%Y-%m-%d', o.created_at)";
    final rows = await db.rawQuery('''
      SELECT $groupExpr as bucket, SUM(oi.price * oi.quantity) as revenue
      FROM orders o JOIN order_items oi ON oi.order_id = o.id
      WHERE o.created_at BETWEEN ? AND ? $storeFilter
      GROUP BY bucket ORDER BY bucket ASC
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return {for (final r in rows) r['bucket'] as String: (r['revenue'] as num).toDouble()};
  }

  Future<List<ProductSaleModel>> getTopProducts({String? storeId, required DateTime from, required DateTime to, int limit = 5}) async {
    final db = await database;
    final storeFilter = storeId != null ? "AND o.store_id = '$storeId'" : '';
    final rows = await db.rawQuery('''
      SELECT oi.product_id, oi.product_name,
             SUM(oi.quantity) as total_qty, SUM(oi.price * oi.quantity) as total_rev
      FROM order_items oi JOIN orders o ON o.id = oi.order_id
      WHERE o.created_at BETWEEN ? AND ? $storeFilter
      GROUP BY oi.product_id, oi.product_name ORDER BY total_qty DESC LIMIT $limit
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return rows.map((r) => ProductSaleModel(
      productId: r['product_id'] as String,
      productName: r['product_name'] as String,
      quantity: (r['total_qty'] as num).toInt(),
      totalRevenue: (r['total_rev'] as num).toDouble(),
    )).toList();
  }

  Future<double> getTotalRevenue({String? storeId, required DateTime from, required DateTime to}) async {
    final db = await database;
    final storeFilter = storeId != null ? "AND o.store_id = '$storeId'" : '';
    final rows = await db.rawQuery('''
      SELECT SUM(oi.price * oi.quantity) as total FROM order_items oi
      JOIN orders o ON o.id = oi.order_id WHERE o.created_at BETWEEN ? AND ? $storeFilter
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return ((rows.first['total'] as num?) ?? 0).toDouble();
  }

  Future<int> getTotalOrderCount({String? storeId, required DateTime from, required DateTime to}) async {
    final db = await database;
    final storeFilter = storeId != null ? "AND store_id = '$storeId'" : '';
    final rows = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM orders WHERE created_at BETWEEN ? AND ? $storeFilter
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return (rows.first['cnt'] as int?) ?? 0;
  }

  // ─── MAPPERS ──────────────────────────────────────────────────────────────
  UserModel _mapUser(Map<String, dynamic> r) => UserModel(
    id: r['id'] as String, name: r['name'] as String, email: r['email'] as String,
    password: r['password'] as String, role: _roleFromString(r['role'] as String),
    storeId: r['store_id'] as String?, storeName: r['store_name'] as String?, phone: r['phone'] as String?,
  );

  Map<String, dynamic> _userToMap(UserModel u) => {
    'id': u.id, 'name': u.name, 'email': u.email, 'password': u.password,
    'role': _roleToString(u.role), 'store_id': u.storeId, 'store_name': u.storeName, 'phone': u.phone,
  };

  StoreModel _mapStore(Map<String, dynamic> r) => StoreModel(
    id: r['id'] as String, name: r['name'] as String, address: r['address'] as String,
    district: r['district'] as String, phone: r['phone'] as String,
    isActive: (r['is_active'] as int) == 1, openedAt: DateTime.parse(r['opened_at'] as String),
  );

  ProductModel _mapProduct(Map<String, dynamic> r) => ProductModel(
    id: r['id'] as String, name: r['name'] as String, price: (r['price'] as num).toDouble(),
    category: _categoryFromString(r['category'] as String), emoji: r['emoji'] as String,
    description: r['description'] as String, storeId: r['store_id'] as String,
    isAvailable: (r['is_available'] as int) == 1,
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
  ShiftType _shiftFromString(String s) {
    switch (s) { case 'morning': return ShiftType.morning; case 'afternoon': return ShiftType.afternoon; default: return ShiftType.evening; }
  }
  String _shiftToString(ShiftType s) {
    switch (s) { case ShiftType.morning: return 'morning'; case ShiftType.afternoon: return 'afternoon'; case ShiftType.evening: return 'evening'; }
  }
  ProductCategory _categoryFromString(String s) {
    switch (s) { case 'iceCream': return ProductCategory.iceCream; case 'tea': return ProductCategory.tea; case 'coffee': return ProductCategory.coffee; case 'dessert': return ProductCategory.dessert; default: return ProductCategory.other; }
  }
}
