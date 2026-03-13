import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../widgets/period_filter_tabs.dart';
import '../../widgets/revenue_chart.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/product_rank_list.dart';

class ManagerRevenueScreen extends StatefulWidget {
  const ManagerRevenueScreen({super.key});
  @override
  State<ManagerRevenueScreen> createState() => _ManagerRevenueScreenState();
}

class _ManagerRevenueScreenState extends State<ManagerRevenueScreen> {
  PeriodFilter _period = PeriodFilter.day;
  late Future<_RevenueData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetch();
  }

  void _load() {
    final f = _fetch();
    if (mounted) setState(() => _dataFuture = f);
  }

  Future<_RevenueData> _fetch() async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<StoreProvider>();
    final storeId = auth.currentUser?.storeId;

    final orders = await provider.getOrdersByPeriod(storeId, _period);
    final chartData = await provider.getChartData(storeId, _period);
    final topProducts = await provider.getTopProducts(storeId, _period, limit: 5);

    final revenue = orders.fold<double>(0, (s, o) => s + o.finalAmount);
    final cashOrders = orders.where(
      (o) => o.payments.any((p) => p.paymentMethod == 'cash'),
    );
    final transferOrders = orders.where(
      (o) => o.payments.any((p) => p.paymentMethod == 'transfer'),
    );
    final cash = cashOrders.fold<double>(
      0,
      (s, o) => s + o.payments
          .where((p) => p.paymentMethod == 'cash')
          .fold<double>(0, (ps, p) => ps + p.amount),
    );
    final avgOrder = orders.isEmpty ? 0.0 : revenue / orders.length;

    return _RevenueData(
      orders: orders,
      chartData: chartData,
      topProducts: topProducts,
      revenue: revenue,
      cash: cash,
      transfer: revenue - cash,
      cashOrderCount: cashOrders.length,
      transferOrderCount: transferOrders.length,
      avgOrder: avgOrder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Báo cáo doanh thu',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _getPeriodLabel(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                PeriodFilterTabs(
                  selected: _period,
                  onChanged: (p) {
                    setState(() => _period = p);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<_RevenueData>(
              future: _dataFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Lỗi: ${snap.error}'));
                }
                final d = snap.data!;
                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  color: const Color(0xFF1A237E),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Total Revenue Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A237E), Color(0xFF283593)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1A237E).withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.attach_money, color: Colors.white70, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Tổng doanh thu',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                FormatUtils.formatCurrency(d.revenue),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _RevenuePill(
                                    label: '${d.orders.length} đơn hàng',
                                    icon: Icons.receipt_long,
                                    color: Colors.white30,
                                    textColor: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  _RevenuePill(
                                    label: 'TB: ${FormatUtils.formatCurrency(d.avgOrder)}',
                                    icon: Icons.trending_up,
                                    color: Colors.white30,
                                    textColor: Colors.white,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Stat cards
                        LayoutBuilder(
                          builder: (ctx, c) {
                            final cols = c.maxWidth > 700 ? 4 : 2;
                            return GridView.count(
                              crossAxisCount: cols,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.3,
                              children: [
                                StatCard(
                                  title: 'Tiền mặt',
                                  value: FormatUtils.formatCurrency(d.cash),
                                  icon: Icons.payments,
                                  color: AppColors.success,
                                  subtitle: '${d.cashOrderCount} đơn',
                                ),
                                StatCard(
                                  title: 'Chuyển khoản',
                                  value: FormatUtils.formatCurrency(d.transfer),
                                  icon: Icons.account_balance,
                                  color: AppColors.info,
                                  subtitle: '${d.transferOrderCount} đơn',
                                ),
                                StatCard(
                                  title: 'Số đơn',
                                  value: '${d.orders.length}',
                                  icon: Icons.receipt_long,
                                  color: AppColors.warning,
                                ),
                                StatCard(
                                  title: 'Trung bình/đơn',
                                  value: FormatUtils.formatCurrency(d.avgOrder),
                                  icon: Icons.bar_chart,
                                  color: AppColors.primary,
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Revenue Chart
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A237E).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.show_chart,
                                      color: Color(0xFF1A237E),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Biểu đồ doanh thu',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              RevenueChart(data: d.chartData, period: _period),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Top products
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.emoji_events,
                                      color: AppColors.warning,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Top sản phẩm bán chạy',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ProductRankList(products: d.topProducts),
                            ],
                          ),
                        ),

                        // Order breakdown by staff
                        const SizedBox(height: 20),
                        _StaffRevenueBreakdown(orders: d.orders),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getPeriodLabel() {
    final now = DateTime.now();
    switch (_period) {
      case PeriodFilter.day:
        return 'Hôm nay ${now.day}/${now.month}/${now.year}';
      case PeriodFilter.week:
        return 'Tuần này';
      case PeriodFilter.month:
        return 'Tháng ${now.month}/${now.year}';
    }
  }
}

// ─── Staff Revenue Breakdown ───────────────────────────────────────────────────
class _StaffRevenueBreakdown extends StatelessWidget {
  final List<SalesOrderModel> orders;
  const _StaffRevenueBreakdown({required this.orders});

  @override
  Widget build(BuildContext context) {
    // Group by staff
    final Map<String, _StaffRevStat> staffMap = {};
    for (final o in orders) {
      final name = o.staffName ?? 'NV#${o.staffUserId}';
      final stat = staffMap[name] ?? _StaffRevStat(name: name);
      stat.orderCount++;
      stat.revenue += o.finalAmount;
      staffMap[name] = stat;
    }
    final staffList = staffMap.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    if (staffList.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people_alt, color: AppColors.success, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Doanh thu theo nhân viên',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...staffList.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final maxRevenue = staffList.first.revenue;
            final progress = maxRevenue > 0 ? s.revenue / maxRevenue : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: idx == 0
                              ? AppColors.warning
                              : (idx == 1 ? AppColors.textSecondary : AppColors.textHint),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${s.orderCount} đơn',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        FormatUtils.formatCurrency(s.revenue),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        idx == 0 ? AppColors.warning : AppColors.info.withValues(alpha: 0.7),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StaffRevStat {
  final String name;
  int orderCount = 0;
  double revenue = 0;
  _StaffRevStat({required this.name});
}

// ─── Revenue Pill ─────────────────────────────────────────────────────────────
class _RevenuePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;

  const _RevenuePill({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data Model ───────────────────────────────────────────────────────────────
class _RevenueData {
  final List<SalesOrderModel> orders;
  final List<ChartEntry> chartData;
  final List<ProductSaleModel> topProducts;
  final double revenue, cash, transfer, avgOrder;
  final int cashOrderCount, transferOrderCount;

  _RevenueData({
    required this.orders,
    required this.chartData,
    required this.topProducts,
    required this.revenue,
    required this.cash,
    required this.transfer,
    required this.cashOrderCount,
    required this.transferOrderCount,
    required this.avgOrder,
  });
}
