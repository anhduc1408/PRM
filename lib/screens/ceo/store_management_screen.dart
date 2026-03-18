import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/store_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../models/product_model.dart';
import '../../models/store_model.dart';
import '../../widgets/period_filter_tabs.dart';

class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  PeriodFilter _period = PeriodFilter.month;
  late Future<_StoreData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<_StoreData> _fetchData() async {
    final provider = context.read<StoreProvider>();
    final stores = await provider.getAllStores();
    final orders = await provider.getOrdersByPeriod(null, _period);

    final storeMetrics = <StoreModel, _StoreMetric>{};
    for (final store in stores) {
      final storeOrders = orders.where((o) => o.storeId == store.id).toList();
      final revenue = storeOrders.fold<double>(0, (s, o) => s + o.finalAmount);
      final topProducts = await provider.getTopProducts(store.id, _period, limit: 3);
      storeMetrics[store] = _StoreMetric(
        revenue: revenue,
        orderCount: storeOrders.length,
        topProducts: topProducts,
      );
    }
    return _StoreData(stores: stores, metrics: storeMetrics);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quản lý cửa hàng', style: Theme.of(context).textTheme.headlineMedium),
                Row(
                  children: [
                    PeriodFilterTabs(selected: _period, onChanged: (p) => setState(() { _period = p; _loadData(); })),
                    const SizedBox(width: 8),
                    IconButton(onPressed: () => setState(_loadData), icon: const Icon(Icons.refresh, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<_StoreData>(
                future: _dataFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Lỗi: ${snap.error}'));
                  }
                  final data = snap.data!;
                  return LayoutBuilder(builder: (context, constraints) {
                    final cols = constraints.maxWidth > 1200 ? 3 : constraints.maxWidth > 700 ? 2 : 1;
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: data.stores.length,
                      itemBuilder: (context, i) {
                        final store = data.stores[i];
                        final metric = data.metrics[store]!;
                        return _StoreCard(
                          store: store,
                          metric: metric,
                          onTap: () => context.go('/ceo/stores/${store.id}'),
                        );
                      },
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final StoreModel store;
  final _StoreMetric metric;
  final VoidCallback onTap;

  const _StoreCard({required this.store, required this.metric, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(store.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: store.status == 'active' ? AppColors.successLight : AppColors.errorLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    store.status == 'active' ? 'Hoạt động' : 'Tạm đóng',
                    style: TextStyle(
                      color: store.status == 'active' ? AppColors.success : AppColors.error,
                      fontSize: 13, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Text(store.address ?? store.code, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Doanh thu', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                      Text(FormatUtils.formatCurrency(metric.revenue),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Đơn hàng', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                    Text('${metric.orderCount}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  ],
                ),
              ],
            ),
            if (metric.topProducts.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 6),
              const Text('Top sản phẩm:', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
              const SizedBox(height: 4),
              ...metric.topProducts.take(2).map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(p.productName, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('×${p.quantity}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ],
                ),
              )),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Xem chi tiết →', style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreData {
  final List<StoreModel> stores;
  final Map<StoreModel, _StoreMetric> metrics;
  _StoreData({required this.stores, required this.metrics});
}

class _StoreMetric {
  final double revenue;
  final int orderCount;
  final List<ProductSaleModel> topProducts;
  _StoreMetric({required this.revenue, required this.orderCount, required this.topProducts});
}
