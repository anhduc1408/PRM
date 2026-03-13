import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/order_model.dart';
import '../../widgets/period_filter_tabs.dart';

class ManagerOrdersScreen extends StatefulWidget {
  const ManagerOrdersScreen({super.key});
  @override
  State<ManagerOrdersScreen> createState() => _ManagerOrdersScreenState();
}

class _ManagerOrdersScreenState extends State<ManagerOrdersScreen> {
  PeriodFilter _period = PeriodFilter.day;
  String? _filterPayment; // null | 'cash' | 'transfer'
  String? _filterStaff;   // null | staffName
  DateTime? _filterDate;
  SalesOrderModel? _selectedOrder;
  late Future<_OrdersData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetch();
  }

  void _load() {
    final f = _fetch();
    if (mounted) setState(() => _dataFuture = f);
  }

  Future<_OrdersData> _fetch() async {
    final storeId = context.read<AuthProvider>().currentUser?.storeId;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime from;
    DateTime to = today
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    if (_filterDate != null) {
      from = DateTime(_filterDate!.year, _filterDate!.month, _filterDate!.day);
      to = from.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    } else {
      switch (_period) {
        case PeriodFilter.day:
          from = today;
          break;
        case PeriodFilter.week:
          from = today.subtract(Duration(days: today.weekday - 1));
          break;
        case PeriodFilter.month:
          from = DateTime(now.year, now.month, 1);
          break;
      }
    }

    final orders = await DatabaseService.instance.getSalesOrders(
      storeId: storeId,
      from: from,
      to: to,
    );

    // Collect staff names for filter dropdown
    final staffNames = orders.map((o) => o.staffName ?? 'NV#${o.staffUserId}').toSet().toList();

    return _OrdersData(orders: orders, staffNames: staffNames);
  }

  List<SalesOrderModel> _filtered(List<SalesOrderModel> orders) {
    return orders.where((o) {
      final matchPayment = _filterPayment == null ||
          o.payments.any((p) => p.paymentMethod == _filterPayment);
      final staffName = o.staffName ?? 'NV#${o.staffUserId}';
      final matchStaff = _filterStaff == null || staffName == _filterStaff;
      return matchPayment && matchStaff;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lịch sử đơn hàng',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    PeriodFilterTabs(
                      selected: _period,
                      onChanged: (p) {
                        setState(() {
                          _period = p;
                          _filterDate = null;
                        });
                        _load();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filter bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: FutureBuilder<_OrdersData>(
              future: _dataFuture,
              builder: (context, snap) {
                final staffNames = snap.data?.staffNames ?? [];
                return Row(
                  children: [
                    // Date picker
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _filterDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 90)),
                            lastDate: DateTime.now(),
                            builder: (ctx, child) => Theme(
                              data: ThemeData(colorSchemeSeed: AppColors.primary),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _filterDate = picked);
                            _load();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _filterDate != null
                                      ? FormatUtils.formatDate(_filterDate!)
                                      : 'Chọn ngày',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              if (_filterDate != null)
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _filterDate = null);
                                    _load();
                                  },
                                  child: const Icon(Icons.close, size: 13, color: AppColors.textHint),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Payment filter
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _filterPayment,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Thanh toán',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tất cả', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'cash', child: Text('Tiền mặt', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'transfer', child: Text('Chuyển khoản', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (v) { setState(() => _filterPayment = v); },
                      ),
                    ),

                    // Staff filter
                    if (staffNames.length > 1) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _filterStaff,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Nhân viên',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceVariant,
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tất cả', style: TextStyle(fontSize: 12))),
                            ...staffNames.map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text(n, style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _filterStaff = v),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          // List
          Expanded(
            child: FutureBuilder<_OrdersData>(
              future: _dataFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Lỗi: ${snap.error}'));
                }
                final data = snap.data!;
                final filtered = _filtered(data.orders);
                final totalRevenue = filtered.fold<double>(0, (s, o) => s + o.finalAmount);

                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  color: const Color(0xFF1A237E),
                  child: Column(
                    children: [
                      // Summary bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        color: AppColors.background,
                        child: Row(
                          children: [
                            _SummaryBadge(
                              label: '${filtered.length} đơn',
                              icon: Icons.receipt_long,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 10),
                            _SummaryBadge(
                              label: FormatUtils.formatCurrency(totalRevenue),
                              icon: Icons.attach_money,
                              color: AppColors.success,
                            ),
                            const Spacer(),
                            if (_filterPayment != null || _filterStaff != null || _filterDate != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _filterPayment = null;
                                    _filterStaff = null;
                                    _filterDate = null;
                                  });
                                  _load();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.clear, size: 12, color: AppColors.error),
                                      SizedBox(width: 4),
                                      Text(
                                        'Xóa lọc',
                                        style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Order list
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('📋', style: TextStyle(fontSize: 40)),
                                    SizedBox(height: 8),
                                    Text(
                                      'Không có đơn hàng',
                                      style: TextStyle(color: AppColors.textHint),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final o = filtered[i];
                                  final isSel = _selectedOrder?.id == o.id;
                                  final payMethod = o.payments.isNotEmpty
                                      ? o.payments.first.paymentMethod
                                      : 'cash';
                                  return GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedOrder = isSel ? null : o,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? const Color(0xFF1A237E).withValues(alpha: 0.04)
                                            : AppColors.surface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: isSel
                                            ? Border.all(
                                                color: const Color(0xFF1A237E).withValues(alpha: 0.4),
                                                width: 1.5,
                                              )
                                            : Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Row(
                                              children: [
                                                // Payment icon
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: payMethod == 'cash'
                                                        ? AppColors.successLight
                                                        : AppColors.infoLight,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Icon(
                                                    payMethod == 'cash'
                                                        ? Icons.payments
                                                        : Icons.account_balance,
                                                    size: 18,
                                                    color: payMethod == 'cash'
                                                        ? AppColors.success
                                                        : AppColors.info,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            o.orderNo,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: AppColors.surfaceVariant,
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              o.staffName ?? 'NV',
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                color: AppColors.textSecondary,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        '${FormatUtils.formatDateTime(o.orderDate)} • ${o.items.length} sp',
                                                        style: const TextStyle(
                                                          color: AppColors.textSecondary,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      FormatUtils.formatCurrency(o.finalAmount),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 15,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Icon(
                                                      isSel ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                                      color: AppColors.textHint,
                                                      size: 16,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Expanded details
                                          if (isSel)
                                            Container(
                                              decoration: const BoxDecoration(
                                                border: Border(top: BorderSide(color: AppColors.divider)),
                                              ),
                                              padding: const EdgeInsets.all(14),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.list_alt, size: 13, color: AppColors.textSecondary),
                                                      const SizedBox(width: 6),
                                                      const Text(
                                                        'Chi tiết sản phẩm:',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppColors.textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ...o.items.map<Widget>(
                                                    (item) => Padding(
                                                      padding: const EdgeInsets.only(bottom: 5),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 4,
                                                            height: 4,
                                                            margin: const EdgeInsets.only(right: 8, top: 1),
                                                            decoration: const BoxDecoration(
                                                              color: AppColors.textHint,
                                                              shape: BoxShape.circle,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              '${item.productName ?? 'Sản phẩm'} ×${item.quantity}',
                                                              style: const TextStyle(fontSize: 12),
                                                            ),
                                                          ),
                                                          Text(
                                                            FormatUtils.formatCurrency(item.lineTotal),
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const Divider(height: 12),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text(
                                                        'Tổng cộng:',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      Text(
                                                        FormatUtils.formatCurrency(o.finalAmount),
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 14,
                                                          color: AppColors.primary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: payMethod == 'cash'
                                                              ? AppColors.successLight
                                                              : AppColors.infoLight,
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              payMethod == 'cash' ? Icons.payments : Icons.account_balance,
                                                              size: 11,
                                                              color: payMethod == 'cash' ? AppColors.success : AppColors.info,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              payMethod == 'cash' ? 'Tiền mặt' : 'Chuyển khoản',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                                color: payMethod == 'cash' ? AppColors.success : AppColors.info,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'NV: ${o.staffName ?? 'N/A'}',
                                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────
class _SummaryBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SummaryBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data Model ───────────────────────────────────────────────────────────────
class _OrdersData {
  final List<SalesOrderModel> orders;
  final List<String> staffNames;

  _OrdersData({required this.orders, required this.staffNames});
}
