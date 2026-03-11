import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/order_model.dart';

class ShiftSummaryScreen extends StatefulWidget {
  const ShiftSummaryScreen({super.key});
  @override
  State<ShiftSummaryScreen> createState() => _ShiftSummaryScreenState();
}

class _ShiftSummaryScreenState extends State<ShiftSummaryScreen> {
  ShiftType _shift = ShiftType.morning;
  DateTime _date = DateTime.now();
  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetch(); // direct assign, no setState in initState
  }
  void _load() {
    final f = _fetch();
    if (mounted) setState(() => _ordersFuture = f);
  }

  Future<List<OrderModel>> _fetch() async {
    final storeId = context.read<AuthProvider>().currentUser?.storeId ?? 'store1';
    final from = DateTime(_date.year, _date.month, _date.day);
    final to = from.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final all = await DatabaseService.instance.getOrders(storeId: storeId, from: from, to: to);
    return all.where((o) => o.shift == _shift).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tổng kết ca làm việc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          // Date + shift picker row
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(data: ThemeData(colorSchemeSeed: AppColors.primary), child: child!));
                if (picked != null) { setState(() => _date = picked); _load(); }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(FormatUtils.formatDate(_date), style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(children: ShiftType.values.map((s) {
                final isSel = _shift == s;
                return Expanded(child: GestureDetector(
                  onTap: () { setState(() => _shift = s); _load(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: isSel ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: Text(s.shortLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? Colors.white : AppColors.textSecondary)),
                  ),
                ));
              }).toList()),
            )),
          ]),
          const SizedBox(height: 20),
          FutureBuilder<List<OrderModel>>(
            future: _ordersFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
              final orders = snap.data ?? [];
              final revenue = orders.fold<double>(0, (s, o) => s + o.totalAmount);
              final cash = orders.where((o) => o.paymentMethod == PaymentMethod.cash).fold<double>(0, (s, o) => s + o.totalAmount);
              final transfer = revenue - cash;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('📋', style: TextStyle(fontSize: 18)), const SizedBox(width: 8),
                      Text('${_shift.shortLabel} — ${FormatUtils.formatDate(_date)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: _SummaryItem(label: 'Tiền mặt', value: FormatUtils.formatCurrency(cash), emoji: '💵', color: AppColors.success)),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryItem(label: 'Chuyển khoản', value: FormatUtils.formatCurrency(transfer), emoji: '🏦', color: AppColors.warning)),
                    ]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('TỔNG CỘNG CA', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(FormatUtils.formatCurrency(revenue), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Text('${orders.length} đơn hàng', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${orders.length} đơn trong ca', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (orders.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Chưa có đơn hàng trong ca này', style: TextStyle(color: AppColors.textHint))))
                    else ...orders.take(20).map<Widget>((o) => Container(
                      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: o.paymentMethod == PaymentMethod.cash ? AppColors.successLight : AppColors.warningLight,
                            borderRadius: BorderRadius.circular(8)),
                          child: Icon(o.paymentMethod == PaymentMethod.cash ? Icons.payments : Icons.account_balance,
                            size: 16, color: o.paymentMethod == PaymentMethod.cash ? AppColors.success : AppColors.warning),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(FormatUtils.formatTime(o.createdAt), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('${o.items.length} sản phẩm', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ])),
                        Text(FormatUtils.formatCurrency(o.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
                      ]),
                    )),
                  ]),
                ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value, emoji; final Color color;
  const _SummaryItem({required this.label, required this.value, required this.emoji, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)), const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ]),
    );
  }
}
