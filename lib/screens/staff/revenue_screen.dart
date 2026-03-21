import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/order_model.dart';
import '../../widgets/period_filter_tabs.dart';
import '../../widgets/revenue_chart.dart';
import '../../widgets/stat_card.dart';

class StaffRevenueScreen extends StatefulWidget {
  const StaffRevenueScreen({super.key});
  @override
  State<StaffRevenueScreen> createState() => _StaffRevenueScreenState();
}

class _StaffRevenueScreenState extends State<StaffRevenueScreen> {
  PeriodFilter _period = PeriodFilter.day;
  late Future<_RevenueData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetch(); // direct assign, no setState in initState
  }
  void _load() {
    final f = _fetch();
    if (mounted) setState(() { _dataFuture = f; });
  }

  Future<_RevenueData> _fetch() async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<StoreProvider>();
    final storeId = auth.currentUser?.storeId;
    final orders = await provider.getOrdersByPeriod(storeId, _period);
    final chartData = await provider.getChartData(storeId, _period);
    final revenue = orders.fold<double>(0, (s, o) => s + o.finalAmount);
    final cash = orders.fold<double>(0, (s, o) => s + o.payments.where((p) => p.paymentMethod == 'cash').fold<double>(0, (ps, p) => ps + p.amount));
    return _RevenueData(orders: orders, chartData: chartData, revenue: revenue, cash: cash, transfer: revenue - cash);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Doanh thu cửa hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            PeriodFilterTabs(selected: _period, onChanged: (p) { setState(() => _period = p); _load(); }),
          ]),
        ),
        Expanded(child: FutureBuilder<_RevenueData>(
          future: _dataFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
            final d = snap.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LayoutBuilder(builder: (ctx, c) {
                  final cols = c.maxWidth > 700 ? 4 : 2;
                  return GridView.count(crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.35, children: [
                    StatCard(title: 'Tổng doanh thu', value: FormatUtils.formatCurrency(d.revenue), icon: Icons.attach_money, color: AppColors.primary),
                    StatCard(title: 'Số đơn', value: '${d.orders.length}', icon: Icons.receipt_long, color: AppColors.info),
                    StatCard(title: 'Tiền mặt', value: FormatUtils.formatCurrency(d.cash), icon: Icons.payments, color: AppColors.success),
                    StatCard(title: 'Chuyển khoản', value: FormatUtils.formatCurrency(d.transfer), icon: Icons.account_balance, color: AppColors.warning),
                  ]);
                }),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Biểu đồ doanh thu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    RevenueChart(data: d.chartData, days: _period == PeriodFilter.day ? 1 : (_period == PeriodFilter.week ? 7 : 30)),
                  ]),
                ),
              ]),
            );
          },
        )),
      ]),
    );
  }
}

class _RevenueData {
  final List<SalesOrderModel> orders;
  final List<ChartEntry> chartData;
  final double revenue, cash, transfer;
  _RevenueData({required this.orders, required this.chartData, required this.revenue, required this.cash, required this.transfer});
}
