import 'package:flutter/material.dart';
import '../../data/database_service.dart';
import '../../models/store_model.dart';
import '../../models/warehouse_model.dart';
import '../../models/product_model.dart';
import '../../models/warehouse_inventory_model.dart';
import '../../models/stock_transfer_model.dart';
import '../../models/category_model.dart';

class WarehouseProvider extends ChangeNotifier {
  List<StoreModel> _stores = [];
  List<WarehouseModel> _warehouses = [];
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  List<WarehouseInventoryModel> _inventory = [];
  List<StockTransferModel> _transfers = [];
  bool _isLoading = false;
  String? _error;

  List<StoreModel> get stores => _stores;
  List<WarehouseModel> get warehouses => _warehouses;
  List<ProductModel> get products => _products;
  List<CategoryModel> get categories => _categories;
  List<WarehouseInventoryModel> get inventory => _inventory;
  List<StockTransferModel> get transfers => _transfers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<WarehouseInventoryModel> get lowStockItems =>
      _inventory.where((i) => i.isLowStock).toList();

  // ─── LOAD ────────────────────────────────────────────────────────────────
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _stores = await DatabaseService.instance.getAllStores();
      _warehouses = await DatabaseService.instance.getAllWarehouses();
      _products = await DatabaseService.instance.getAllProducts();
      _categories = await DatabaseService.instance.getAllCategories();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadInventoryForWarehouse(int warehouseId) async {
    _inventory = await DatabaseService.instance.getInventoryByWarehouse(warehouseId);
    notifyListeners();
  }

  Future<void> loadTransfers() async {
    _transfers = await DatabaseService.instance.getAllStockTransfers();
    notifyListeners();
  }

  // ─── PRODUCT CRUD ────────────────────────────────────────────────────────
  Future<void> addProduct({
    required String sku,
    required String name,
    required int categoryId,
    required String unit,
    required double costPrice,
    required double sellingPrice,
    required String emoji,
    String? barcode,
  }) async {
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('products', {
      'sku': sku, 'name': name, 'category_id': categoryId, 'unit': unit,
      'cost_price': costPrice, 'selling_price': sellingPrice,
      'emoji': emoji, 'barcode': barcode, 'status': 'active',
      'created_at': now, 'updated_at': now,
    });
    _products = await DatabaseService.instance.getAllProducts();
    notifyListeners();
  }

  Future<void> updateProduct(ProductModel product, {
    required String name, required int categoryId, required String unit,
    required double costPrice, required double sellingPrice,
    required String emoji, String? barcode,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.update('products', {
      'name': name, 'category_id': categoryId, 'unit': unit,
      'cost_price': costPrice, 'selling_price': sellingPrice,
      'emoji': emoji, 'barcode': barcode,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [product.id]);
    _products = await DatabaseService.instance.getAllProducts();
    notifyListeners();
  }

  Future<void> toggleProductStatus(ProductModel product) async {
    final db = await DatabaseService.instance.database;
    final newStatus = product.status == 'active' ? 'inactive' : 'active';
    await db.update('products', {
      'status': newStatus, 'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [product.id]);
    _products = await DatabaseService.instance.getAllProducts();
    notifyListeners();
  }

  Future<void> deleteProduct(int productId) async {
    final db = await DatabaseService.instance.database;
    await db.delete('products', where: 'id = ?', whereArgs: [productId]);
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
  }

  // ─── INVENTORY ADJUST ────────────────────────────────────────────────────
  Future<void> adjustInventory(int warehouseId, int productId, int newQty) async {
    await DatabaseService.instance.updateInventoryQuantity(warehouseId, productId, newQty);
    final idx = _inventory.indexWhere(
        (i) => i.warehouseId == warehouseId && i.productId == productId);
    if (idx != -1) {
      _inventory[idx].quantity = newQty;
      notifyListeners();
    }
  }

  // ─── TRANSFERS ────────────────────────────────────────────────────────────
  Future<bool> createTransfer({
    required int fromWarehouseId,
    required int toWarehouseId,
    required int requestedBy,
    required List<Map<String, int>> items, // [{productId, qty}]
    String? note,
  }) async {
    try {
      final transferItems = items.map((e) => StockTransferItemModel(
        id: 0, transferId: 0, productId: e['productId']!,
        estimateQuantity: e['qty']!,
      )).toList();
      final model = StockTransferModel(
        id: 0, fromWarehouseId: fromWarehouseId, toWarehouseId: toWarehouseId,
        requestedBy: requestedBy, status: 'pending', note: note,
        createdAt: DateTime.now(), items: transferItems,
      );
      await DatabaseService.instance.insertStockTransfer(model);
      await loadTransfers();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── CHECKER: RECEIVE TRANSFER ────────────────────────────────────────────
  /// Tải danh sách phiếu giao hàng đến kho [toWarehouseId]
  Future<List<StockTransferModel>> loadIncomingTransfers(int toWarehouseId) async {
    return DatabaseService.instance.getTransfersByToWarehouse(toWarehouseId);
  }

  /// Xác nhận nhận hàng - cập nhật actual_qty + tồn kho + status
  Future<bool> receiveTransfer({
    required int transferId,
    required int toWarehouseId,
    required int receivedBy,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await DatabaseService.instance.receiveTransfer(
        transferId: transferId,
        toWarehouseId: toWarehouseId,
        receivedBy: receivedBy,
        items: items,
      );
      await loadTransfers();
      await loadInventoryForWarehouse(toWarehouseId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────
  List<ProductModel> productsForCategory(int categoryId) =>
      _products.where((p) => p.categoryId == categoryId).toList();

  WarehouseModel? mainWarehouse() =>
      _warehouses.where((w) => w.type == 'main').firstOrNull;

  List<WarehouseModel> warehousesForStore(int storeId) =>
      _warehouses.where((w) => w.storeId == storeId).toList();

  String nextSku() {
    final count = _products.length + 1;
    return 'PRD${count.toString().padLeft(3, '0')}';
  }
}
