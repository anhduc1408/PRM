import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/revenue_chart.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/product_rank_list.dart';

class ManagerRevenueScreen extends StatefulWidget {
  const ManagerRevenueScreen({super.key});
  @override
  State<ManagerRevenueScreen> createState() => _ManagerRevenueScreenState();
}

class _ManagerRevenueScreenState extends State<ManagerRevenueScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  late Future<_RevenueData> _dataFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month, now.day);
    _dataFuture = _fetch();
  }

  void _load() {
    final f = _fetch();
    if (mounted) setState(() { _dataFuture = f; });
  }

  Future<_RevenueData> _fetch() async {
    final auth = context.read<AuthProvider>();
    final storeId = auth.currentUser?.storeId;

    final now = DateTime.now();
    DateTime from = _startDate ?? DateTime(now.year, now.month, 1);
    DateTime to = _endDate ?? DateTime(now.year, now.month, now.day);
    to = DateTime(to.year, to.month, to.day).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    final orders = await DatabaseService.instance.getSalesOrders(
      storeId: storeId, from: from, to: to,
    );
    final chartData = await DatabaseService.instance.getRevenueChartDataByDateRange(storeId, from, to);
    final topProducts = await DatabaseService.instance.getTopProducts(
      storeId: storeId, from: from, to: to, limit: 5,
    );

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

  // Date filter logic moved inline to DateRangeFilterBar

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Web-like Header
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Báo cáo doanh thu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Xem hiệu suất bán hàng của cửa hàng',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    )
                  ],
                ),
                DateRangeFilterBar(
                  initialFrom: _startDate,
                  initialTo: _endDate,
                  onChanged: (val) {
                    setState(() {
                      _startDate = val.start;
                      _endDate = val.end;
                    });
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
                final daysCount = _endDate != null && _startDate != null ? _endDate!.difference(_startDate!).inDays + 1 : 30;

                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  color: const Color(0xFF1A237E),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Stat cards
                        LayoutBuilder(
                          builder: (ctx, c) {
                            final cols = c.maxWidth > 800 ? 5 : 2;
                            return GridView.count(
                              crossAxisCount: cols,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.5,
                              children: [
                                _WebStatCard(
                                   title: 'Tổng doanh thu', 
                                   value: FormatUtils.formatCurrency(d.revenue), 
                                   subtitle: '${d.orders.length} đơn', 
                                   icon: Icons.attach_money,
                                   color: AppColors.primary
                                ),
                                _WebStatCard(
                                   title: 'Trung bình/đơn', 
                                   value: FormatUtils.formatCurrency(d.avgOrder), 
                                   subtitle: 'N/A', 
                                   icon: Icons.functions,
                                   color: AppColors.info
                                ),
                                _WebStatCard(
                                   title: 'Tiền mặt', 
                                   value: FormatUtils.formatCurrency(d.cash), 
                                   subtitle: '${d.cashOrderCount} đơn', 
                                   icon: Icons.money,
                                   color: AppColors.success
                                ),
                                _WebStatCard(
                                   title: 'Chuyển khoản', 
                                   value: FormatUtils.formatCurrency(d.transfer), 
                                   subtitle: '${d.transferOrderCount} đơn', 
                                   icon: Icons.account_balance,
                                   color: AppColors.warning
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        Row(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              // Chart
                              Expanded(
                                 flex: 2,
                                 child: Card(
                                    color: Colors.white,
                                    margin: EdgeInsets.zero,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                                    child: Padding(
                                       padding: const EdgeInsets.all(20),
                                       child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                             const Text('Biểu đồ doanh thu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                             const SizedBox(height: 24),
                                             RevenueChart(data: d.chartData, days: daysCount),
                                          ]
                                       )
                                    )
                                 )
                              ),
                              const SizedBox(width: 24),
                              
                              // Top products
                              Expanded(
                                 flex: 1,
                                 child: Card(
                                    color: Colors.white,
                                    margin: EdgeInsets.zero,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                                    child: Padding(
                                       padding: const EdgeInsets.all(20),
                                       child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                             const Text('Top sản phẩm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                             const SizedBox(height: 16),
                                             ProductRankList(products: d.topProducts),
                                          ]
                                       )
                                    )
                                 )
                              )
                           ]
                        ),
                        
                        const SizedBox(height: 24),

                        // Order breakdown by staff
                        Card(
                           color: Colors.white,
                           margin: EdgeInsets.zero,
                           elevation: 0,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                           child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                    const Text('Hiệu suất nhân viên', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    _StaffRevenueBreakdown(orders: d.orders),
                                 ]
                              )
                           )
                        )
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
}

class _WebStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _WebStatCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
               Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 18, color: color),
               )
            ],
          ),
          Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
             ],
          )
        ],
      ),
    );
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

    if (staffList.isEmpty) return const Text('Không có dữ liệu bán hàng cho giai đoạn này.', style: TextStyle(color: AppColors.textHint));

    return Column(
      children: staffList.asMap().entries.map((entry) {
        final idx = entry.key;
        final s = entry.value;
        final maxRevenue = staffList.first.revenue;
        final progress = maxRevenue > 0 ? s.revenue / maxRevenue : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: idx == 0
                          ? AppColors.warning
                          : (idx == 1 ? AppColors.textSecondary : AppColors.textHint),
                      shape: BoxShape.circle,
                      boxShadow: [
                         if(idx==0) BoxShadow(color: AppColors.warning.withOpacity(0.3), blurRadius: 4, offset:const Offset(0, 2))
                      ]
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${s.orderCount} đơn',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    FormatUtils.formatCurrency(s.revenue),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    idx == 0 ? AppColors.warning : AppColors.info,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StaffRevStat {
  final String name;
  int orderCount = 0;
  double revenue = 0;
  _StaffRevStat({required this.name});
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
