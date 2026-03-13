import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/store_model.dart';
import '../../models/user_model.dart';
import '../../data/database_service.dart';
import '../constants/enums.dart';

class StoreProvider extends ChangeNotifier {

  // ─── DATE RANGE HELPERS ───────────────────────────────────────────────────
  DateTimeRange _rangeFor(PeriodFilter period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case PeriodFilter.day:
        return DateTimeRange(start: today, end: today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)));
      case PeriodFilter.week:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: startOfWeek, end: today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)));
      case PeriodFilter.month:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)));
    }
  }

  // ─── FETCH ORDERS ─────────────────────────────────────────────────────────
  Future<List<SalesOrderModel>> getOrdersByPeriod(int? storeId, PeriodFilter period) async {
    final range = _rangeFor(period);
    return DatabaseService.instance.getSalesOrders(storeId: storeId, from: range.start, to: range.end);
  }

  Future<List<SalesOrderModel>> getOrdersForStore(int storeId) async {
    return DatabaseService.instance.getSalesOrders(storeId: storeId);
  }

  // ─── ADD ORDER ────────────────────────────────────────────────────────────
  Future<void> addOrder(SalesOrderModel order) async {
    await DatabaseService.instance.insertSalesOrder(order);
    notifyListeners();
  }

  // ─── CHART DATA ───────────────────────────────────────────────────────────
  Future<List<ChartEntry>> getChartData(int? storeId, PeriodFilter period) async {
    final entries = await DatabaseService.instance.getRevenueChartData(storeId, period);
    final range = _rangeFor(period);

    if (period == PeriodFilter.day) {
      return List.generate(16, (i) {
        final h = i + 7; // 7:00 - 22:00
        final key = h.toString().padLeft(2, '0');
        final match = entries.firstWhere((e) => e.label == key, orElse: () => const ChartEntry(label: '', value: 0));
        return ChartEntry(label: '${h}h', value: match.value);
      });
    } else if (period == PeriodFilter.week) {
      const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
      return List.generate(7, (i) {
        final day = range.start.add(Duration(days: i));
        final key = day.weekday.toString(); // SQLite strftime('%w') = 0=sunday
        final match = entries.firstWhere((e) => e.label == key, orElse: () => const ChartEntry(label: '', value: 0));
        return ChartEntry(label: days[day.weekday - 1], value: match.value);
      });
    } else {
      final daysInMonth = DateTime(range.start.year, range.start.month + 1, 0).day;
      return List.generate(daysInMonth, (i) {
        final key = (i + 1).toString().padLeft(2, '0');
        final match = entries.firstWhere((e) => e.label == key, orElse: () => const ChartEntry(label: '', value: 0));
        return ChartEntry(label: '${i + 1}', value: match.value);
      });
    }
  }

  // ─── TOP PRODUCTS ─────────────────────────────────────────────────────────
  Future<List<ProductSaleModel>> getTopProducts(int? storeId, PeriodFilter period, {int limit = 5}) async {
    return DatabaseService.instance.getTopProducts(storeId: storeId, limit: limit);
  }

  // ─── SUMMARY STATS ────────────────────────────────────────────────────────
  Future<double> getTotalRevenue(int? storeId, PeriodFilter period) async {
    final range = _rangeFor(period);
    return DatabaseService.instance.getTotalRevenue(storeId: storeId, from: range.start, to: range.end);
  }

  Future<int> getTotalOrderCount(int? storeId, PeriodFilter period) async {
    final range = _rangeFor(period);
    return DatabaseService.instance.getTotalOrderCount(storeId: storeId, from: range.start, to: range.end);
  }

  // ─── STORES & USERS ───────────────────────────────────────────────────────
  Future<List<StoreModel>> getAllStores() => DatabaseService.instance.getAllStores();
  Future<List<ProductModel>> getActiveProducts() => DatabaseService.instance.getProductsActive();
  Future<List<UserModel>> getAllUsers() => DatabaseService.instance.getAllUsers();
}
