import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/store_model.dart';
import '../../models/user_model.dart';
import '../../data/database_service.dart';
import '../constants/enums.dart';

class StoreProvider extends ChangeNotifier {
  // In-memory order cache for current session (newly added orders)
  final List<OrderModel> _sessionOrders = [];

  // ─── DATE RANGE HELPERS ───────────────────────────────────────────────────
  DateTimeRange _rangeFor(PeriodFilter period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case PeriodFilter.day:
        return DateTimeRange(
          start: today,
          end: today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)),
        );
      case PeriodFilter.week:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(
          start: startOfWeek,
          end: today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)),
        );
      case PeriodFilter.month:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)),
        );
    }
  }

  // ─── FETCH ORDERS ─────────────────────────────────────────────────────────
  Future<List<OrderModel>> getOrdersByPeriod(String? storeId, PeriodFilter period) async {
    final range = _rangeFor(period);
    final dbOrders = await DatabaseService.instance.getOrders(
      storeId: storeId,
      from: range.start,
      to: range.end,
    );
    // Merge session orders
    final session = _sessionOrders.where((o) {
      final inStore = storeId == null || o.storeId == storeId;
      final inRange = !o.createdAt.isBefore(range.start) && !o.createdAt.isAfter(range.end);
      return inStore && inRange;
    }).toList();

    return [...session, ...dbOrders];
  }

  Future<List<OrderModel>> getOrdersForStore(String storeId) async {
    final dbOrders = await DatabaseService.instance.getOrders(storeId: storeId);
    final session = _sessionOrders.where((o) => o.storeId == storeId).toList();
    return [...session, ...dbOrders];
  }

  // ─── ADD ORDER ────────────────────────────────────────────────────────────
  Future<void> addOrder(OrderModel order) async {
    await DatabaseService.instance.insertOrder(order);
    _sessionOrders.insert(0, order);
    notifyListeners();
  }

  // ─── CHART DATA ───────────────────────────────────────────────────────────
  Future<List<ChartEntry>> getChartData(String? storeId, PeriodFilter period) async {
    final range = _rangeFor(period);
    final groupBy = period == PeriodFilter.day ? 'hour' : 'day';
    final data = await DatabaseService.instance.getRevenueGrouped(
      storeId: storeId,
      from: range.start,
      to: range.end,
      groupBy: groupBy,
    );

    if (period == PeriodFilter.day) {
      return List.generate(24, (h) {
        final key = h.toString().padLeft(2, '0');
        return ChartEntry(label: '${h}h', value: data[key] ?? 0);
      }).where((e) => e.value > 0 || (int.parse(e.label.replaceAll('h', '')) >= 7 && int.parse(e.label.replaceAll('h', '')) <= 22)).toList();
    } else if (period == PeriodFilter.week) {
      return List.generate(7, (i) {
        final day = range.start.add(Duration(days: i));
        final key = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
        const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
        return ChartEntry(label: days[day.weekday - 1], value: data[key] ?? 0);
      });
    } else {
      final daysInMonth = DateTime(range.start.year, range.start.month + 1, 0).day;
      return List.generate(daysInMonth, (i) {
        final day = DateTime(range.start.year, range.start.month, i + 1);
        final key = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
        return ChartEntry(label: '${i + 1}', value: data[key] ?? 0);
      });
    }
  }

  // ─── TOP PRODUCTS ─────────────────────────────────────────────────────────
  Future<List<ProductSaleModel>> getTopProducts(String? storeId, PeriodFilter period, {int limit = 5}) async {
    final range = _rangeFor(period);
    return DatabaseService.instance.getTopProducts(
      storeId: storeId,
      from: range.start,
      to: range.end,
      limit: limit,
    );
  }

  // ─── SUMMARY STATS ────────────────────────────────────────────────────────
  Future<double> getTotalRevenue(String? storeId, PeriodFilter period) async {
    final range = _rangeFor(period);
    return DatabaseService.instance.getTotalRevenue(
      storeId: storeId,
      from: range.start,
      to: range.end,
    );
  }

  Future<int> getTotalOrderCount(String? storeId, PeriodFilter period) async {
    final range = _rangeFor(period);
    return DatabaseService.instance.getTotalOrderCount(
      storeId: storeId,
      from: range.start,
      to: range.end,
    );
  }

  // ─── STORES & USERS ───────────────────────────────────────────────────────
  Future<List<StoreModel>> getAllStores() => DatabaseService.instance.getAllStores();

  Future<List<ProductModel>> getProductsForStore(String storeId) =>
      DatabaseService.instance.getProductsForStore(storeId);

  Future<List<UserModel>> getAllUsers() => DatabaseService.instance.getAllUsers();
}

/// Simple data class for chart entries
class ChartEntry {
  final String label;
  final double value;
  const ChartEntry({required this.label, required this.value});
}
