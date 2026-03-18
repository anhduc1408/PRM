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

class CeoDashboardScreen extends StatefulWidget {
  const CeoDashboardScreen({super.key});

  @override
  State<CeoDashboardScreen> createState() => _CeoDashboardScreenState();
}

class _CeoDashboardScreenState extends State<CeoDashboardScreen> {
  PeriodFilter _period = PeriodFilter.month;
  late Future<_DashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<_DashboardData> _fetchData() async {
    final provider = context.read<StoreProvider>();
    final stores = await provider.getAllStores();
    final orders = await provider.getOrdersByPeriod(null, _period);
    final chartData = await provider.getChartData(null, _period);
    final topProducts = await provider.getTopProducts(null, _period, limit: 5);

    final totalRevenue = orders.fold<double>(0, (s, o) => s + o.finalAmount);
    final cashRevenue = orders.fold<double>(0, (s, o) => s + o.payments.where((p) => p.paymentMethod == 'cash').fold<double>(0, (ps, p) => ps + p.amount));
    final transferRevenue = totalRevenue - cashRevenue;
    final activeStores = stores.where((s) => s.status == 'active').length;

    // Per-store revenue
    final storeRevenues = <StoreModel, double>{};
    for (final store in stores) {
      final storeOrders = orders.where((o) => o.storeId == store.id);
      storeRevenues[store] = storeOrders.fold(0, (s, o) => s + o.finalAmount);
    }

    return _DashboardData(
      stores: stores,
      orders: orders,
      chartData: chartData,
      topProducts: topProducts,
      totalRevenue: totalRevenue,
      cashRevenue: cashRevenue,
      transferRevenue: transferRevenue,
      activeStores: activeStores,
      storeRevenues: storeRevenues,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tổng quan chuỗi Mixue',
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text(_period == PeriodFilter.day
                        ? 'Hôm nay, ${FormatUtils.formatDate(DateTime.now())}'
                        : _period == PeriodFilter.week
                            ? 'Tuần này'
                            : 'Tháng ${DateTime.now().month}/${DateTime.now().year}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    PeriodFilterTabs(
                      selected: _period,
                      onChanged: (p) => setState(() {
                        _period = p;
                        _loadData();
                      }),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => setState(_loadData),
                      icon: const Icon(Icons.refresh, color: AppColors.primary),
                      tooltip: 'Làm mới',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: FutureBuilder<_DashboardData>(
              future: _dataFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                        const SizedBox(height: 12),
                        Text('Lỗi: ${snap.error}'),
                        TextButton(onPressed: () => setState(_loadData), child: const Text('Thử lại')),
                      ],
                    ),
                  );
                }
                final data = snap.data!;
                return _buildBody(data);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(_DashboardData d) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat cards grid
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 900 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                StatCard(
                  title: 'Tổng doanh thu',
                  value: FormatUtils.formatCurrency(d.totalRevenue),
                  icon: Icons.attach_money,
                  color: AppColors.primary,
                ),
                StatCard(
                  title: 'Tổng đơn hàng',
                  value: '${d.orders.length}',
                  icon: Icons.receipt_long,
                  color: AppColors.info,
                ),
                StatCard(
                  title: 'Cửa hàng hoạt động',
                  value: '${d.activeStores}/${d.stores.length}',
                  icon: Icons.store,
                  color: AppColors.success,
                ),
                StatCard(
                  title: 'Chuyển khoản',
                  value: FormatUtils.formatCurrency(d.transferRevenue),
                  icon: Icons.account_balance,
                  color: AppColors.warning,
                ),
              ],
            );
          }),

          const SizedBox(height: 24),

          // Chart + top products side by side (or stacked)
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final chartSection = _buildChartCard(d);
            final topSection = _buildTopProductsCard(d.topProducts);
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: chartSection),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: topSection),
                ],
              );
            }
            return Column(children: [chartSection, const SizedBox(height: 16), topSection]);
          }),

          const SizedBox(height: 24),

          // Per-store revenue
          _buildStoreRevenueTable(d),
        ],
      ),
    );
  }

  Widget _buildChartCard(_DashboardData d) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Biểu đồ doanh thu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          RevenueChart(data: d.chartData, days: _period == PeriodFilter.day ? 1 : (_period == PeriodFilter.week ? 7 : 30)),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(List<ProductSaleModel> top) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sản phẩm bán chạy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ProductRankList(products: top),
        ],
      ),
    );
  }

  Widget _buildStoreRevenueTable(_DashboardData d) {
    final sorted = d.storeRevenues.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalRev = d.totalRevenue;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Doanh thu từng cửa hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...sorted.map((entry) {
            final pct = totalRev > 0 ? entry.value / totalRev : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: entry.key.status == 'active' ? AppColors.success : AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(entry.key.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                      Text(FormatUtils.formatCurrency(entry.value),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        entry.key.status == 'active' ? AppColors.primary : AppColors.textHint,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  Text('${(pct * 100).toStringAsFixed(1)}% tổng doanh thu',
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DashboardData {
  final List<StoreModel> stores;
  final List<SalesOrderModel> orders;
  final List<ChartEntry> chartData;
  final List<ProductSaleModel> topProducts;
  final double totalRevenue;
  final double cashRevenue;
  final double transferRevenue;
  final int activeStores;
  final Map<StoreModel, double> storeRevenues;

  _DashboardData({
    required this.stores,
    required this.orders,
    required this.chartData,
    required this.topProducts,
    required this.totalRevenue,
    required this.cashRevenue,
    required this.transferRevenue,
    required this.activeStores,
    required this.storeRevenues,
  });
}
