import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/warehouse_provider.dart';
import '../../models/warehouse_model.dart';
import '../../models/stock_transfer_model.dart';

class WarehouseTransferScreen extends StatefulWidget {
  const WarehouseTransferScreen({super.key});

  @override
  State<WarehouseTransferScreen> createState() => _WarehouseTransferScreenState();
}

class _WarehouseTransferScreenState extends State<WarehouseTransferScreen> {
  int? _fromWarehouseId;
  int? _toWarehouseId;
  final Map<int, int> _selectedItems = {}; // productId -> qty
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WarehouseProvider>().loadTransfers().then((_) {
        // Auto-select main warehouse for inventory checker
        if (mounted) {
          final role = context.read<AuthProvider>().currentUser?.role;
          if (role == UserRole.inventoryChecker) {
            final mainWh = context.read<WarehouseProvider>().mainWarehouse();
            if (mainWh != null) {
              setState(() => _fromWarehouseId = mainWh.id);
            }
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_fromWarehouseId == null || _toWarehouseId == null || _selectedItems.isEmpty) return;
    if (_fromWarehouseId == _toWarehouseId) {
      _showSnack('Kho đi và đến phải khác nhau!', isError: true);
      return;
    }
    setState(() => _submitting = true);
    final user = context.read<AuthProvider>().currentUser;
    final items = _selectedItems.entries
        .where((e) => e.value > 0)
        .map((e) => {'productId': e.key, 'qty': e.value})
        .toList();
    final ok = await context.read<WarehouseProvider>().createTransfer(
      fromWarehouseId: _fromWarehouseId!,
      toWarehouseId: _toWarehouseId!,
      requestedBy: user?.id ?? 1,
      items: items,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    if (mounted) {
      setState(() {
        _submitting = false;
        if (ok) {
          _selectedItems.clear();
          _fromWarehouseId = null;
          _toWarehouseId = null;
          _noteCtrl.clear();
        }
      });
      _showSnack(ok ? '✅ Đã tạo phiếu phân phối!' : '❌ Có lỗi xảy ra!', isError: !ok);
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
    final prov = context.watch<WarehouseProvider>();
    final warehouses = prov.warehouses;
    final products = prov.products.where((p) => p.status == 'active').toList();
    final transfers = prov.transfers;

    final filteredProducts = _searchCtrl.text.isEmpty
        ? products
        : products.where((p) => p.name.toLowerCase().contains(_searchCtrl.text.toLowerCase())).toList();

    final hasItems = _selectedItems.values.any((q) => q > 0);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ─── Create Transfer Form ──────────────────────────────────────
        _SectionCard(
          title: '🚚 Tạo phiếu phân phối',
          children: [
            // From Warehouse
            const Text('Kho xuất hàng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            if (context.read<AuthProvider>().currentUser?.role == UserRole.inventoryChecker)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  warehouses.firstWhere((w) => w.id == _fromWarehouseId, orElse: () => warehouses.first).name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              )
            else
              _WarehouseDropdown(
                value: _fromWarehouseId,
                label: '-- Chọn kho xuất --',
                warehouses: warehouses,
                onChanged: (v) => setState(() => _fromWarehouseId = v),
              ),
            const SizedBox(height: 12),

            // To Warehouse
            const Text('Kho nhận hàng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            _WarehouseDropdown(
              value: _toWarehouseId,
              label: '-- Chọn kho nhận --',
              // Inventory checker can only transfer to STORES (not back to main)
              warehouses: warehouses.where((w) {
                if (context.read<AuthProvider>().currentUser?.role == UserRole.inventoryChecker) {
                  return w.type == 'store' && w.id != _fromWarehouseId;
                }
                return w.id != _fromWarehouseId;
              }).toList(),
              onChanged: (v) => setState(() => _toWarehouseId = v),
            ),
            const SizedBox(height: 12),

            // Products
            const Text('Chọn sản phẩm & số lượng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Tìm sản phẩm...', prefixIcon: Icon(Icons.search, size: 16), isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            // Product list (limited height)
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: filteredProducts.isEmpty
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Không có sản phẩm', style: TextStyle(color: AppColors.textHint)),
                    ))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredProducts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = filteredProducts[i];
                        final qty = _selectedItems[p.id] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(children: [
                            Text(p.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(p.sku, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                              ],
                            )),
                            // Qty stepper
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.error),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: qty > 0 ? () => setState(() => _selectedItems[p.id] = qty - 1) : null,
                            ),
                            Container(
                              width: 36, alignment: Alignment.center,
                              child: Text('$qty', style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800,
                                color: qty > 0 ? const Color(0xFF2D7A50) : AppColors.textHint,
                              )),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF2D7A50)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _selectedItems[p.id] = qty + 1),
                            ),
                          ]),
                        );
                      },
                    ),
            ),

            // Selected summary
            if (hasItems) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D7A50).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedItems.values.where((v) => v > 0).length} loại · '
                  '${_selectedItems.values.fold(0, (a, b) => a + b)} đơn vị',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D7A50)),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Note
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
            ),
            const SizedBox(height: 16),

            // Submit button
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: (_fromWarehouseId == null || _toWarehouseId == null || !hasItems || _submitting)
                    ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D7A50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  _submitting ? 'Đang tạo...' : 'Tạo phiếu phân phối',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Transfer History ──────────────────────────────────────────
        _SectionCard(
          title: '📋 Lịch sử phân phối',
          children: transfers.isEmpty
              ? [
                  const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Column(children: [
                      Text('🚚', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 8),
                      Text('Chưa có phiếu phân phối', style: TextStyle(color: AppColors.textHint)),
                    ]),
                  )),
                ]
              : transfers.map((t) => _TransferCard(transfer: t)).toList(),
        ),
      ],
    );
  }
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _WarehouseDropdown extends StatelessWidget {
  final int? value;
  final String label;
  final List<WarehouseModel> warehouses;
  final ValueChanged<int?> onChanged;
  const _WarehouseDropdown({this.value, required this.label, required this.warehouses, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value,
      hint: Text(label),
      isExpanded: true,
      itemHeight: null, // Allow auto height
      decoration: InputDecoration(
        isDense: true, // Use dense layout to reduce default padding
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: warehouses.map((w) => DropdownMenuItem(
        value: w.id,
        child: Text(
          '${w.name} (${w.storeName ?? w.code})',
          style: const TextStyle(fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      )).toList(),
      onChanged: onChanged,
    );
  }
}

class _TransferCard extends StatelessWidget {
  final StockTransferModel transfer;
  const _TransferCard({required this.transfer});

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
      case 'pending': return 'Chờ duyệt';
      case 'approved': return 'Đã duyệt';
      case 'in_transit': return 'Đang vận chuyển';
      case 'received': return 'Đã nhận';
      case 'cancelled': return 'Đã hủy';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = transfer;
    final color = _statusColor(t.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              '${t.fromWarehouseName ?? '?'} → ${t.toWarehouseName ?? '?'}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(_statusLabel(t.status), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.person_outline, size: 12, color: AppColors.textHint),
          const SizedBox(width: 4),
          Text(t.requestedByName ?? 'N/A', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          const Spacer(),
          Text(
            '${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}',
            style: const TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
        ]),
        if (t.items.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final item in t.items.take(3))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface, borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('${item.productName ?? '?'} ×${item.estimateQuantity}',
                    style: const TextStyle(fontSize: 11)),
              ),
            if (t.items.length > 3)
              Text('+${t.items.length - 3} khác',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ]),
        ],
        if (t.note != null && t.note!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(t.note!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }
}
