import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/store_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/store_model.dart';
import '../../widgets/period_filter_tabs.dart';
import '../../widgets/product_rank_list.dart';
import '../../widgets/revenue_chart.dart';
import '../../widgets/stat_card.dart';

class StoreDetailScreen extends StatefulWidget {
  final String storeId; // kept as String for router param
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  PeriodFilter _period = PeriodFilter.month;
  late Future<_DetailData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<_DetailData> _fetchData() async {
    final provider = context.read<StoreProvider>();
    final storeIdInt = int.tryParse(widget.storeId) ?? 1;
    final store = await provider.getAllStores().then(
        (list) => list.firstWhere((s) => s.id == storeIdInt, orElse: () => StoreModel(id: storeIdInt, code: '?', name: '?', createdAt: DateTime.now(), updatedAt: DateTime.now())));
    final orders = await provider.getOrdersByPeriod(storeIdInt, _period);
    final chartData = await provider.getChartData(storeIdInt, _period);
    final topProducts = await provider.getTopProducts(storeIdInt, _period, limit: 5);

    final revenue = orders.fold<double>(0, (s, o) => s + o.finalAmount);
    final cashRevenue = orders.fold<double>(0, (s, o) => s + o.payments.where((p) => p.paymentMethod == 'cash').fold<double>(0, (ps, p) => ps + p.amount));
    final transferRevenue = revenue - cashRevenue;

    return _DetailData(
      store: store,
      orders: orders,
      chartData: chartData,
      topProducts: topProducts,
      revenue: revenue,
      cashRevenue: cashRevenue,
      transferRevenue: transferRevenue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<_DetailData>(
        future: _dataFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
          final d = snap.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.store.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                            Text(d.store.address ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            Text('${d.store.address ?? ''} • ${d.store.phone ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: d.store.status == 'active' ? AppColors.successLight : AppColors.errorLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              d.store.status == 'active' ? 'Hoạt động' : 'Tạm đóng',
                              style: TextStyle(color: d.store.status == 'active' ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          PeriodFilterTabs(selected: _period, onChanged: (p) => setState(() { _period = p; _loadData(); })),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                LayoutBuilder(builder: (ctx, constraints) {
                  final cols = constraints.maxWidth > 700 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      StatCard(title: 'Doanh thu', value: FormatUtils.formatCurrency(d.revenue), icon: Icons.attach_money, color: AppColors.primary),
                      StatCard(title: 'Tiền mặt', value: FormatUtils.formatCurrency(d.cashRevenue), icon: Icons.payments, color: AppColors.success),
                      StatCard(title: 'Chuyển khoản', value: FormatUtils.formatCurrency(d.transferRevenue), icon: Icons.account_balance, color: AppColors.warning),
                      StatCard(title: 'Đơn hàng', value: '${d.orders.length}', icon: Icons.receipt_long, color: AppColors.info),
                    ],
                  );
                }),

                const SizedBox(height: 20),
                LayoutBuilder(builder: (ctx, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final chart = Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Biểu đồ doanh thu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 16),
                      RevenueChart(data: d.chartData, period: _period),
                    ]),
                  );
                  final topProd = Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Sản phẩm bán chạy', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 12),
                      ProductRankList(products: d.topProducts),
                    ]),
                  );
                  if (isWide) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 3, child: chart),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: topProd),
                    ]);
                  }
                  return Column(children: [chart, const SizedBox(height: 16), topProd]);
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailData {
  final StoreModel store;
  final List<SalesOrderModel> orders;
  final List<ChartEntry> chartData;
  final List<ProductSaleModel> topProducts;
  final double revenue, cashRevenue, transferRevenue;
  _DetailData({required this.store, required this.orders, required this.chartData, required this.topProducts, required this.revenue, required this.cashRevenue, required this.transferRevenue});
}
