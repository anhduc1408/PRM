import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/warehouse_provider.dart';
import '../../models/stock_transfer_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Màn hình CHECKER - Xác nhận nhận hàng từ phiếu chuyển kho
// ─────────────────────────────────────────────────────────────────────────────
class CheckerReceiveScreen extends StatefulWidget {
  const CheckerReceiveScreen({super.key});

  @override
  State<CheckerReceiveScreen> createState() => _CheckerReceiveScreenState();
}

class _CheckerReceiveScreenState extends State<CheckerReceiveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<StockTransferModel> _allTransfers = [];
  bool _loading = true;
  int? _myWarehouseId;

  static const _statusOrder = ['pending', 'approved', 'in_transit', 'received', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final prov = context.read<WarehouseProvider>();
    // Checker quản lý kho tổng (main warehouse)
    final mainWh = prov.mainWarehouse();
    _myWarehouseId = mainWh?.id;

    if (_myWarehouseId != null) {
      final transfers = await prov.loadIncomingTransfers(_myWarehouseId!);
      if (mounted) {
        setState(() {
          _allTransfers = transfers;
          _loading = false;
        });
      }
    } else {
      setState(() => _loading = false);
    }
  }

  List<StockTransferModel> _byStatus(String status) =>
      _allTransfers.where((t) => t.status == status).toList();

  List<StockTransferModel> get _pendingOrInTransit => _allTransfers
      .where((t) => t.status == 'pending' || t.status == 'in_transit' || t.status == 'approved')
      .toList()
    ..sort((a, b) {
      final ai = _statusOrder.indexOf(a.status);
      final bi = _statusOrder.indexOf(b.status);
      return ai.compareTo(bi);
    });

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingOrInTransit.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // ─── Banner header ───────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A4731), Color(0xFF2D7A50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('📥', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Xác nhận nhận hàng',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('Kho Tổng · ${_allTransfers.length} phiếu',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
                ]),
              ),
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$pendingCount chờ xử lý',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Làm mới',
                onPressed: _loadData,
              ),
            ]),
            const SizedBox(height: 10),
            // TabBar nằm trong header
            TabBar(
              controller: _tabCtrl,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'Chờ xử lý (${_pendingOrInTransit.length})'),
                Tab(text: 'Đã nhận (${_byStatus('received').length})'),
                Tab(text: 'Đã hủy (${_byStatus('cancelled').length})'),
              ],
            ),
          ]),
        ),

        // ─── TabBarView ────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D7A50)))
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // Tab 0: Chờ xử lý
                    _TransferList(
                      transfers: _pendingOrInTransit,
                      isActionable: true,
                      onRefresh: _loadData,
                      myWarehouseId: _myWarehouseId ?? 0,
                    ),
                    // Tab 1: Đã nhận
                    _TransferList(
                      transfers: _byStatus('received'),
                      isActionable: false,
                      onRefresh: _loadData,
                      myWarehouseId: _myWarehouseId ?? 0,
                    ),
                    // Tab 2: Đã hủy
                    _TransferList(
                      transfers: _byStatus('cancelled'),
                      isActionable: false,
                      onRefresh: _loadData,
                      myWarehouseId: _myWarehouseId ?? 0,
                    ),
                  ],
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Danh sách phiếu chuyển kho
// ─────────────────────────────────────────────────────────────────────────────
class _TransferList extends StatelessWidget {
  final List<StockTransferModel> transfers;
  final bool isActionable;
  final VoidCallback onRefresh;
  final int myWarehouseId;

  const _TransferList({
    required this.transfers,
    required this.isActionable,
    required this.onRefresh,
    required this.myWarehouseId,
  });

  @override
  Widget build(BuildContext context) {
    if (transfers.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(isActionable ? '🎉' : '📋', style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text(
            isActionable ? 'Không có phiếu nào cần xử lý' : 'Chưa có dữ liệu',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          if (isActionable) ...[
            const SizedBox(height: 6),
            const Text('Tất cả phiếu đã được xử lý xong!',
                style: TextStyle(color: AppColors.textHint, fontSize: 12)),
          ],
        ]),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF2D7A50),
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        itemCount: transfers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _TransferCard(
          transfer: transfers[i],
          isActionable: isActionable,
          myWarehouseId: myWarehouseId,
          onRefresh: onRefresh,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card hiển thị 1 phiếu chuyển kho
// ─────────────────────────────────────────────────────────────────────────────
class _TransferCard extends StatelessWidget {
  final StockTransferModel transfer;
  final bool isActionable;
  final int myWarehouseId;
  final VoidCallback onRefresh;

  const _TransferCard({
    required this.transfer,
    required this.isActionable,
    required this.myWarehouseId,
    required this.onRefresh,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return AppColors.info;
      case 'in_transit': return AppColors.warning;
      case 'received': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending': return '⏳ Chờ duyệt';
      case 'approved': return '✅ Đã duyệt';
      case 'in_transit': return '🚚 Đang vận chuyển';
      case 'received': return '📦 Đã nhận';
      case 'cancelled': return '❌ Đã hủy';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = transfer;
    final color = _statusColor(t.status);
    final totalEstimate = t.items.fold<int>(0, (sum, i) => sum + i.estimateQuantity);
    final totalActual = t.items.fold<int>(0, (sum, i) => sum + i.actualQuantity);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8, offset: const Offset(0, 3),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ─── Header của card ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Row(children: [
                  Icon(Icons.local_shipping_rounded, size: 15, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${t.fromWarehouseName ?? '?'} → ${t.toWarehouseName ?? '?'}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel(t.status),
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.person_outline, size: 12, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text('Yêu cầu bởi: ${t.requestedByName ?? 'N/A'}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              const Spacer(),
              Icon(Icons.schedule, size: 12, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                '${t.createdAt.day.toString().padLeft(2,'0')}/${t.createdAt.month.toString().padLeft(2,'0')}/${t.createdAt.year}',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ]),
          ]),
        ),

        // ─── Danh sách sản phẩm ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.inventory_2_outlined, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text('${t.items.length} sản phẩm',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const Spacer(),
              Text('Ước tính: $totalEstimate đv',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              if (t.status == 'received') ...[
                const SizedBox(width: 10),
                Text('Thực tế: $totalActual đv',
                    style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
              ],
            ]),
            const SizedBox(height: 8),
            // Hiển thị tối đa 3 items
            ...t.items.take(3).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Container(
                  width: 6, height: 6, margin: const EdgeInsets.only(right: 8, top: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(item.productName ?? 'SP #${item.productId}',
                      style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                ),
                Text(' ×${item.estimateQuantity}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                if (t.status == 'received' && item.actualQuantity > 0) ...[
                  const Text(' → ', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                  Text('${item.actualQuantity} (TT)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                ],
              ]),
            )),
            if (t.items.length > 3)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 14),
                child: Text('+${t.items.length - 3} sản phẩm khác...',
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ),
          ]),
        ),

        // ─── Ghi chú ───────────────────────────────────────────────────────
        if (t.note != null && t.note!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.notes, size: 13, color: AppColors.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(t.note!,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ),

        // ─── Ngày nhận (nếu đã nhận) ───────────────────────────────────────
        if (t.status == 'received' && t.receivedAt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(children: [
              const Icon(Icons.check_circle, size: 13, color: AppColors.success),
              const SizedBox(width: 4),
              Text(
                'Đã xác nhận: ${t.receivedAt!.day.toString().padLeft(2,'0')}/'
                '${t.receivedAt!.month.toString().padLeft(2,'0')}/'
                '${t.receivedAt!.year} '
                '${t.receivedAt!.hour.toString().padLeft(2,'0')}:'
                '${t.receivedAt!.minute.toString().padLeft(2,'0')}',
                style: const TextStyle(fontSize: 11, color: AppColors.success),
              ),
            ]),
          ),

        // ─── Action button ─────────────────────────────────────────────────
        if (isActionable) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              width: double.infinity, height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _showReceiveDialog(context, t),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D7A50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Xác nhận nhận hàng',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ),
        ] else
          const SizedBox(height: 14),
      ]),
    );
  }

  void _showReceiveDialog(BuildContext context, StockTransferModel transfer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReceiveSheet(
        transfer: transfer,
        myWarehouseId: myWarehouseId,
        onSuccess: onRefresh,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet xác nhận nhận hàng: nhập actual_quantity từng item
// ─────────────────────────────────────────────────────────────────────────────
class _ReceiveSheet extends StatefulWidget {
  final StockTransferModel transfer;
  final int myWarehouseId;
  final VoidCallback onSuccess;

  const _ReceiveSheet({
    required this.transfer,
    required this.myWarehouseId,
    required this.onSuccess,
  });

  @override
  State<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<_ReceiveSheet> {
  late List<TextEditingController> _ctrls;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo controller với estimate_quantity làm giá trị mặc định
    _ctrls = widget.transfer.items.map((item) =>
        TextEditingController(text: '${item.estimateQuantity}')).toList();
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validate tất cả ô nhập
    for (int i = 0; i < _ctrls.length; i++) {
      final val = int.tryParse(_ctrls[i].text.trim());
      if (val == null || val < 0) {
        _showSnack('Số lượng không hợp lệ: ${widget.transfer.items[i].productName}', isError: true);
        return;
      }
    }

    setState(() => _submitting = true);

    final user = context.read<AuthProvider>().currentUser;
    final prov = context.read<WarehouseProvider>();

    final items = <Map<String, int>>[];
    for (int i = 0; i < widget.transfer.items.length; i++) {
      final item = widget.transfer.items[i];
      items.add({
        'itemId': item.id,
        'productId': item.productId,
        'actualQty': int.parse(_ctrls[i].text.trim()),
      });
    }

    final ok = await prov.receiveTransfer(
      transferId: widget.transfer.id,
      toWarehouseId: widget.myWarehouseId,
      receivedBy: user?.id ?? 0,
      items: items,
    );

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Xác nhận nhận hàng thành công! Tồn kho đã được cập nhật.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ));
      } else {
        _showSnack('❌ Có lỗi xảy ra. Vui lòng thử lại!', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    final totalItems = t.items.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // ─── Handle bar ─────────────────────────────────────────────────
          Container(
            width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),

          // ─── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A4731), Color(0xFF2D7A50)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Xác nhận nhận hàng',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('${t.fromWarehouseName ?? '?'} → ${t.toWarehouseName ?? '?'}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ]),
          ),

          const Divider(height: 16),

          // ─── Info banner ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2D7A50).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2D7A50).withValues(alpha: 0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.info_outline, size: 14, color: Color(0xFF2D7A50)),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('Nhập số lượng thực tế nhận được cho từng sản phẩm.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF2D7A50), fontWeight: FontWeight.w500)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  'Tổng $totalItems sản phẩm · Ngày tạo: ${t.createdAt.day.toString().padLeft(2,'0')}/'
                  '${t.createdAt.month.toString().padLeft(2,'0')}/${t.createdAt.year}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Bảng nhập số lượng ─────────────────────────────────────────
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: const [
              Expanded(flex: 4, child: Text('Sản phẩm',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              SizedBox(
                width: 60,
                child: Text('Ước tính', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
              SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Text('Thực nhận', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2D7A50))),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 8),
          ),

          // Item list
          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              padding: EdgeInsets.only(
                left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              itemCount: t.items.length,
              separatorBuilder: (context, index) => const Divider(height: 14, thickness: 0.5),
              itemBuilder: (_, i) {
                final item = t.items[i];
                return _ItemRow(
                  item: item,
                  controller: _ctrls[i],
                );
              },
            ),
          ),

          // ─── Submit button ───────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20,
                MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10, offset: const Offset(0, -3),
              )],
            ),
            child: Column(children: [
              // Quick fill button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : () {
                    for (int i = 0; i < _ctrls.length; i++) {
                      _ctrls[i].text = '${t.items[i].estimateQuantity}';
                    }
                    setState(() {});
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2D7A50),
                    side: const BorderSide(color: Color(0xFF2D7A50)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Đặt tất cả = số ước tính',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7A50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                    _submitting ? 'Đang xác nhận...' : 'Xác nhận nhận hàng',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row nhập số lượng thực tế của 1 item
// ─────────────────────────────────────────────────────────────────────────────
class _ItemRow extends StatefulWidget {
  final StockTransferItemModel item;
  final TextEditingController controller;

  const _ItemRow({required this.item, required this.controller});

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  bool _isOver = false; // actual > estimate
  bool _isUnder = false; // actual < estimate

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _onChanged();
  }

  void _onChanged() {
    final val = int.tryParse(widget.controller.text.trim());
    if (mounted) {
      setState(() {
        _isOver = val != null && val > widget.item.estimateQuantity;
        _isUnder = val != null && val < widget.item.estimateQuantity;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  Color get _fieldColor {
    if (_isOver) return AppColors.info;
    if (_isUnder) return AppColors.warning;
    return const Color(0xFF2D7A50);
  }

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Product info
      Expanded(
        flex: 4,
        child: Row(children: [
          if (_isOver)
            const Icon(Icons.arrow_upward, size: 13, color: AppColors.info)
          else if (_isUnder)
            const Icon(Icons.arrow_downward, size: 13, color: AppColors.warning)
          else
            const Icon(Icons.check, size: 13, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.item.productName ?? 'SP #${widget.item.productId}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (widget.item.productSku != null)
                Text(widget.item.productSku!,
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            ]),
          ),
        ]),
      ),

      // Estimate quantity
      SizedBox(
        width: 60,
        child: Text('${widget.item.estimateQuantity}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                color: AppColors.textSecondary)),
      ),
      const SizedBox(width: 8),

      // Actual quantity input
      SizedBox(
        width: 80,
        child: Column(children: [
          // Stepper buttons + input
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _fieldColor.withValues(alpha: 0.4), width: 1.5),
              borderRadius: BorderRadius.circular(10),
              color: _fieldColor.withValues(alpha: 0.05),
            ),
            child: Row(children: [
              // Decrease button
              GestureDetector(
                onTap: () {
                  final val = int.tryParse(widget.controller.text.trim()) ?? 0;
                  if (val > 0) widget.controller.text = '${val - 1}';
                },
                child: Container(
                  width: 26, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.remove, size: 14, color: _fieldColor),
                ),
              ),
              // Text input
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _fieldColor),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                  ),
                ),
              ),
              // Increase button
              GestureDetector(
                onTap: () {
                  final val = int.tryParse(widget.controller.text.trim()) ?? 0;
                  widget.controller.text = '${val + 1}';
                },
                child: Container(
                  width: 26, height: 36,
                  decoration: BoxDecoration(
                    color: _fieldColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.add, size: 14, color: _fieldColor),
                ),
              ),
            ]),
          ),
          // Label under the input
          if (_isOver || _isUnder)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                _isOver ? '⬆ Vượt dự kiến' : '⬇ Thiếu hàng',
                style: TextStyle(fontSize: 9, color: _fieldColor, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ]),
      ),
    ]);
  }
}
