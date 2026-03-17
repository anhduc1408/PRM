import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/warehouse_inventory_model.dart';
import '../../models/warehouse_model.dart';

class ManagerInventoryScreen extends StatefulWidget {
  const ManagerInventoryScreen({super.key});
  @override
  State<ManagerInventoryScreen> createState() => _ManagerInventoryScreenState();
}

class _ManagerInventoryScreenState extends State<ManagerInventoryScreen> {
  late Future<_InventoryData> _dataFuture;
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all' | 'low' | 'ok'
  WarehouseModel? _selectedWarehouse;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetch();
  }

  void _load() {
    final f = _fetch();
    if (mounted) setState(() => _dataFuture = f);
  }

  Future<_InventoryData> _fetch() async {
    final storeId = context.read<AuthProvider>().currentUser?.storeId;
    final allWarehouses = storeId != null
        ? await DatabaseService.instance.getWarehousesByStore(storeId)
        : await DatabaseService.instance.getAllWarehouses();

    final warehouses = allWarehouses.where((w) => w.type != 'main').toList();

    final whId = _selectedWarehouse?.id ?? (warehouses.isNotEmpty ? warehouses.first.id : null);
    final items = whId != null
        ? await DatabaseService.instance.getInventoryByWarehouse(whId)
        : <WarehouseInventoryModel>[];

    return _InventoryData(
      warehouses: warehouses,
      items: items,
      selectedWarehouseId: whId,
    );
  }

  List<WarehouseInventoryModel> _filtered(List<WarehouseInventoryModel> items) {
    return items.where((item) {
      final matchSearch = _searchQuery.isEmpty ||
          (item.productName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (item.productSku?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchStatus = _filterStatus == 'all' ||
          (_filterStatus == 'low' && item.quantity <= item.minQuantity) ||
          (_filterStatus == 'ok' && item.quantity > item.minQuantity);
      return matchSearch && matchStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<_InventoryData>(
        future: _dataFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Lỗi: ${snap.error}'));
          }
          final data = snap.data!;
          final filtered = _filtered(data.items);
          final lowStockCount = data.items.where((i) => i.quantity <= i.minQuantity).length;
          final totalQty = data.items.fold<int>(0, (s, i) => s + i.quantity);

          return RefreshIndicator(
            onRefresh: () async => _load(),
            color: const Color(0xFF1A237E),
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tồn kho cửa hàng',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh, color: Color(0xFF1A237E)),
                            ),
                          ],
                        ),

                        // Summary row
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _InventorySummaryCard(
                                label: 'Tổng tồn kho',
                                value: '$totalQty',
                                icon: Icons.inventory_2_outlined,
                                color: AppColors.info,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _InventorySummaryCard(
                                label: 'Sắp hết hàng',
                                value: '$lowStockCount',
                                icon: Icons.warning_amber_outlined,
                                color: lowStockCount > 0 ? AppColors.error : AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _InventorySummaryCard(
                                label: 'Sản phẩm',
                                value: '${data.items.length}',
                                icon: Icons.category_outlined,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),

                        // Warehouse selector
                        if (data.warehouses.length > 1) ...[
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: data.warehouses.map((wh) {
                                final isSelected = (wh.id == data.selectedWarehouseId);
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedWarehouse = wh;
                                      _dataFuture = _fetch();
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF1A237E)
                                          : AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF1A237E)
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.warehouse_outlined,
                                          size: 13,
                                          color: isSelected ? Colors.white : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          wh.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? Colors.white : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Search + filter bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Tìm tên sản phẩm, mã SKU...',
                            prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textHint),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _FilterChip(
                              label: 'Tất cả (${data.items.length})',
                              selected: _filterStatus == 'all',
                              onTap: () => setState(() => _filterStatus = 'all'),
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '⚠️ Sắp hết ($lowStockCount)',
                              selected: _filterStatus == 'low',
                              onTap: () => setState(() => _filterStatus = 'low'),
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '✅ Đủ hàng (${data.items.length - lowStockCount})',
                              selected: _filterStatus == 'ok',
                              onTap: () => setState(() => _filterStatus = 'ok'),
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Count
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Text(
                      'Hiển thị ${filtered.length} sản phẩm',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

                // Inventory list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final item = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: _InventoryItemCard(item: item),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),

                if (filtered.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            Text('📦', style: TextStyle(fontSize: 40)),
                            SizedBox(height: 8),
                            Text(
                              'Không tìm thấy sản phẩm',
                              style: TextStyle(color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Inventory Item Card ───────────────────────────────────────────────────────
class _InventoryItemCard extends StatelessWidget {
  final WarehouseInventoryModel item;
  const _InventoryItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isLow = item.quantity <= item.minQuantity;
    final isCritical = item.quantity <= (item.minQuantity * 0.5).ceil();
    final stock = item.quantity;
    final minStock = item.minQuantity;
    final pct = (stock / (minStock * 2)).clamp(0.0, 1.0);

    final statusColor = isCritical
        ? AppColors.error
        : (isLow ? AppColors.warning : AppColors.success);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLow ? statusColor.withValues(alpha: 0.3) : AppColors.border.withValues(alpha: 0.5),
          width: isLow ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Product icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.inventory_2,
                    color: statusColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName ?? 'SP không tên',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          item.productSku ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.warehouseName ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Stock number + badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stock}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isCritical
                          ? '🚨 Hết gần'
                          : (isLow ? '⚠️ Sắp hết' : '✅ Đủ hàng'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tồn: $stock / Tối thiểu: $minStock',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Cập nhật: ${FormatUtils.formatDate(item.updatedAt)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────
class _InventorySummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InventorySummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Data Model ───────────────────────────────────────────────────────────────
class _InventoryData {
  final List<WarehouseModel> warehouses;
  final List<WarehouseInventoryModel> items;
  final int? selectedWarehouseId;

  _InventoryData({
    required this.warehouses,
    required this.items,
    required this.selectedWarehouseId,
  });
}
