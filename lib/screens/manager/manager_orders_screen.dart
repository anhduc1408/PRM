import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/order_model.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/period_filter_tabs.dart';

class ManagerOrdersScreen extends StatefulWidget {
  const ManagerOrdersScreen({super.key});
  @override
  State<ManagerOrdersScreen> createState() => _ManagerOrdersScreenState();
}

class _ManagerOrdersScreenState extends State<ManagerOrdersScreen> {
  String? _filterPayment;
  String? _filterStaff;
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 1;
  static const int _itemsPerPage = 15;
  late Future<_OrdersData> _dataFuture;

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
    if (mounted) setState(() => _dataFuture = f);
  }

  Future<_OrdersData> _fetch() async {
    final storeId = context.read<AuthProvider>().currentUser?.storeId;
    final now = DateTime.now();
    DateTime from = _startDate ?? DateTime(now.year, now.month, 1);
    DateTime to = _endDate ?? DateTime(now.year, now.month, now.day);
    
    // Include the whole end day
    to = DateTime(to.year, to.month, to.day).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    final orders = await DatabaseService.instance.getSalesOrders(
      storeId: storeId,
      from: from,
      to: to,
    );

    final staffNames = orders.map((o) => o.staffName ?? 'NV#${o.staffUserId}').toSet().toList();
    return _OrdersData(orders: orders, staffNames: staffNames);
  }

  List<SalesOrderModel> _filtered(List<SalesOrderModel> orders) {
    return orders.where((o) {
      final matchPayment = _filterPayment == null || o.payments.any((p) => p.paymentMethod == _filterPayment);
      final staffName = o.staffName ?? 'NV#${o.staffUserId}';
      final matchStaff = _filterStaff == null || staffName == _filterStaff;
      return matchPayment && matchStaff;
    }).toList();
  }

  // Filter logic moved inline to DateRangeFilterBar in build()

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<_OrdersData>(
        future: _dataFuture,
        builder: (context, snap) {
           Widget content;
           if (snap.connectionState == ConnectionState.waiting) {
             content = const Center(child: CircularProgressIndicator());
           } else if (snap.hasError) {
             content = Center(child: Text('Lỗi: ${snap.error}'));
           } else {
             final data = snap.data!;
             final filtered = _filtered(data.orders);
             final totalRevenue = filtered.fold<double>(0, (s, o) => s + o.finalAmount);
             
             final totalPages = (filtered.isEmpty ? 1 : (filtered.length / _itemsPerPage).ceil());
             if (_currentPage > totalPages) _currentPage = totalPages;
             final startIndex = (_currentPage - 1) * _itemsPerPage;
             int endIndex = startIndex + _itemsPerPage;
             if (endIndex > filtered.length) endIndex = filtered.length;
             final paginatedItems = filtered.isEmpty ? <SalesOrderModel>[] : filtered.sublist(startIndex, endIndex);

             // A web-like Card containing filters and table
             content = Card(
               margin: const EdgeInsets.all(8),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               elevation: 2,
               color: Colors.white,
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   // Filter Bar
                   Padding(
                     padding: const EdgeInsets.all(16),
                     child: Row(
                       children: [
                         // Date Range Filter
                         Expanded(
                           child: DateRangeFilterBar(
                             initialFrom: _startDate,
                             initialTo: _endDate,
                             onChanged: (val) {
                               setState(() {
                                 _startDate = val.start;
                                 _endDate = val.end;
                                 _currentPage = 1;
                               });
                               _load();
                             },
                           ),
                         ),
                         const SizedBox(width: 16),
                         // Payment Filter
                         Expanded(
                           child: DropdownButtonFormField<String?>(
                             value: _filterPayment,
                             decoration: const InputDecoration(
                               labelText: 'Thanh toán',
                               border: OutlineInputBorder(),
                               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                             ),
                             items: const [
                               DropdownMenuItem(value: null, child: Text('Tất cả')),
                               DropdownMenuItem(value: 'cash', child: Text('Tiền mặt')),
                               DropdownMenuItem(value: 'transfer', child: Text('Chuyển khoản')),
                             ],
                             onChanged: (v) { setState(() { _filterPayment = v; _currentPage = 1; }); },
                           ),
                         ),
                         const SizedBox(width: 16),
                         // Staff Filter
                         Expanded(
                           child: data.staffNames.isNotEmpty ? DropdownButtonFormField<String?>(
                             value: _filterStaff,
                             decoration: const InputDecoration(
                               labelText: 'Nhân viên',
                               border: OutlineInputBorder(),
                               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                             ),
                             items: [
                               const DropdownMenuItem(value: null, child: Text('Tất cả')),
                               ...data.staffNames.map((n) => DropdownMenuItem(value: n, child: Text(n))),
                             ],
                             onChanged: (v) => setState(() { _filterStaff = v; _currentPage = 1; }),
                           ) : const SizedBox.shrink(),
                         ),
                         const SizedBox(width: 16),
                         // Summary Widgets
                         Expanded(
                           child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             decoration: BoxDecoration(
                               color: AppColors.successLight.withAlpha(50),
                               borderRadius: BorderRadius.circular(8),
                             ),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.end,
                               children: [
                                 Text('Tổng số đơn: ${filtered.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                 Text('Doanh thu: ${FormatUtils.formatCurrency(totalRevenue)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 16)),
                               ],
                             ),
                           ),
                         ),
                       ],
                     ),
                   ),
                   const Divider(height: 1),
                   Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Không có đơn hàng nào'))
                          : SingleChildScrollView(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                      child: DataTable(
                                        showCheckboxColumn: false,
                                        headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                                        columns: const [
                                          DataColumn(label: Text('Mã ĐH', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Thời gian', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Nhân viên', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Sản phẩm', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Thanh toán', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Tổng tiền', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                        ],
                                        rows: paginatedItems.map((o) {
                                          final payMethod = o.payments.isNotEmpty ? o.payments.first.paymentMethod : 'cash';
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(o.orderNo, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary))),
                                              DataCell(Text(FormatUtils.formatDateTime(o.orderDate))),
                                              DataCell(Text(o.staffName ?? 'NV#${o.staffUserId}')),
                                              DataCell(Text('${o.items.length} sp')),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: payMethod == 'cash' ? AppColors.successLight : AppColors.infoLight,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    payMethod == 'cash' ? 'Tiền mặt' : 'Chuyển khoản',
                                                    style: TextStyle(fontSize: 12, color: payMethod == 'cash' ? AppColors.success : AppColors.info, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                              DataCell(Text(FormatUtils.formatCurrency(o.finalAmount), style: const TextStyle(fontWeight: FontWeight.bold))),
                                            ],
                                            onSelectChanged: (_) => _showOrderDetails(o),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                   const Divider(height: 1),
                   // Pagination
                   Padding(
                     padding: const EdgeInsets.all(16),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.end,
                       children: [
                         IconButton(
                           icon: const Icon(Icons.chevron_left),
                           onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                         ),
                         Text('Trang $_currentPage / $totalPages'),
                         IconButton(
                           icon: const Icon(Icons.chevron_right),
                           onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                         ),
                       ],
                     ),
                   ),
                 ],
               ),
             );
           }

           return Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               Container(
                 padding: const EdgeInsets.all(8),
                 color: Colors.white,
                 child: const Text('Lịch sử đơn hàng', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
               ),
               Expanded(child: content),
             ],
           );
        },
      ),
    );
  }

  void _showOrderDetails(SalesOrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Chi tiết đơn hàng ${order.orderNo}'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('${item.productName ?? 'SP'} x${item.quantity}')),
                    Text(FormatUtils.formatCurrency(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng cộng:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(FormatUtils.formatCurrency(order.finalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
        ],
      ),
    );
  }
}

class _OrdersData {
  final List<SalesOrderModel> orders;
  final List<String> staffNames;
  _OrdersData({required this.orders, required this.staffNames});
}

