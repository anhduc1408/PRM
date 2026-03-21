import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/order_model.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  DateTime? _filterDate;
  String? _filterPayment; // 'cash' | 'transfer' | null
  SalesOrderModel? _selectedOrder;
  late Future<List<SalesOrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetch();
  }

  void _load() {
    final f = _fetch();
    if (mounted) setState(() { _ordersFuture = f; });
  }

  Future<List<SalesOrderModel>> _fetch() async {
    final storeId = context.read<AuthProvider>().currentUser?.storeId;
    DateTime? from, to;
    if (_filterDate != null) {
      from = DateTime(_filterDate!.year, _filterDate!.month, _filterDate!.day);
      to = from.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    }
    final orders = await DatabaseService.instance.getSalesOrders(storeId: storeId, from: from, to: to);
    if (_filterPayment != null) {
      return orders.where((o) => o.payments.any((p) => p.paymentMethod == _filterPayment)).toList();
    }
    return orders;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Lịch sử bán hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _filterDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 90)), lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(data: ThemeData(colorSchemeSeed: AppColors.primary), child: child!));
                setState(() { _filterDate = picked; }); _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 15, color: AppColors.textSecondary), const SizedBox(width: 8),
                  Expanded(child: Text(_filterDate != null ? FormatUtils.formatDate(_filterDate!) : 'Tất cả ngày', style: const TextStyle(fontSize: 13))),
                  if (_filterDate != null) GestureDetector(onTap: () { setState(() => _filterDate = null); _load(); }, child: const Icon(Icons.close, size: 14, color: AppColors.textHint)),
                ]),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String?>(
              value: _filterPayment,
              decoration: const InputDecoration(labelText: 'Thanh toán', isDense: true),
              items: const [
                DropdownMenuItem(value: null, child: Text('Tất cả')),
                DropdownMenuItem(value: 'cash', child: Text('Tiền mặt')),
                DropdownMenuItem(value: 'transfer', child: Text('Chuyển khoản')),
              ],
              onChanged: (v) { setState(() => _filterPayment = v); _load(); },
            )),
          ]),
          const SizedBox(height: 16),
          Expanded(child: FutureBuilder<List<SalesOrderModel>>(
            future: _ordersFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
              final orders = snap.data ?? [];
              if (orders.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('📋', style: TextStyle(fontSize: 40)), SizedBox(height: 8), Text('Không có đơn hàng', style: TextStyle(color: AppColors.textHint)),
              ]));
              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, i) {
                  final o = orders[i];
                  final isSel = _selectedOrder?.id == o.id;
                  final payMethod = o.payments.isNotEmpty ? o.payments.first.paymentMethod : 'cash';
                  return GestureDetector(
                    onTap: () => setState(() { _selectedOrder = isSel ? null : o; }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: isSel ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                      ),
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: payMethod == 'cash' ? AppColors.successLight : AppColors.warningLight,
                                borderRadius: BorderRadius.circular(8)),
                              child: Icon(payMethod == 'cash' ? Icons.payments : Icons.account_balance,
                                size: 18, color: payMethod == 'cash' ? AppColors.success : AppColors.warning),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(o.orderNo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('${FormatUtils.formatDateTime(o.orderDate)} • ${o.items.length} sp', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ])),
                            Text(FormatUtils.formatCurrency(o.finalAmount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
                            const SizedBox(width: 8),
                            Icon(isSel ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textHint, size: 18),
                          ]),
                        ),
                        if (isSel) Container(
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Chi tiết đơn:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ...o.items.map<Widget>((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(children: [
                                Expanded(child: Text('${item.productName ?? 'SP'} ×${item.quantity}', style: const TextStyle(fontSize: 12))),
                                Text(FormatUtils.formatCurrency(item.lineTotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ]),
                            )),
                            const Divider(),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('Tổng cộng:', style: TextStyle(fontWeight: FontWeight.w700)),
                              Text(FormatUtils.formatCurrency(o.finalAmount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ]),
                          ]),
                        ),
                      ]),
                    ),
                  );
                },
              );
            },
          )),
        ]),
      ),
    );
  }
}
