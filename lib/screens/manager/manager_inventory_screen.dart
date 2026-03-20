// src/screens/manager/manager_inventory_screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../data/database_service.dart';
import '../../models/warehouse_inventory_model.dart';
import '../../models/warehouse_model.dart';
import '../../core/utils/format_utils.dart';

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
    
    if (_selectedWarehouse == null && warehouses.isNotEmpty) {
      _selectedWarehouse = warehouses.first;
    }

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
           if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
           if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
           final data = snap.data!;
           final filtered = _filtered(data.items);
           final lowStockCount = data.items.where((i) => i.quantity <= i.minQuantity).length;
           final totalQty = data.items.fold<int>(0, (s, i) => s + i.quantity);

           return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       const Text('Tồn kho cửa hàng', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                       if (data.warehouses.isNotEmpty) 
                         DropdownMenu<WarehouseModel>(
                           initialSelection: _selectedWarehouse,
                           onSelected: (wh) {
                             if (wh != null) {
                               setState(() => _selectedWarehouse = wh);
                               _load();
                             }
                           },
                           dropdownMenuEntries: data.warehouses.map((w) => 
                              DropdownMenuEntry(value: w, label: w.name)
                           ).toList(),
                           leadingIcon: const Icon(Icons.warehouse_outlined),
                           inputDecorationTheme: InputDecorationTheme(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                           ),
                         )
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                     padding: const EdgeInsets.all(24),
                     child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Summary row
                          Row(
                            children: [
                              Expanded(child: _InventorySummaryCard(label: 'Tổng tồn kho', value: '$totalQty', icon: Icons.inventory_2_outlined, color: AppColors.info)),
                              const SizedBox(width: 16),
                              Expanded(child: _InventorySummaryCard(label: 'Sắp hết hàng', value: '$lowStockCount', icon: Icons.warning_amber_outlined, color: lowStockCount > 0 ? AppColors.error : AppColors.success)),
                              const SizedBox(width: 16),
                              Expanded(child: _InventorySummaryCard(label: 'Số Mẫu SP', value: '${data.items.length}', icon: Icons.category_outlined, color: AppColors.success)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Web-like Card enclosing Datatable and Filters
                          Card(
                            color: Colors.white,
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                            child: Column(
                               crossAxisAlignment: CrossAxisAlignment.stretch,
                               children: [
                                  // Toolbar (Search & Filter)
                                  Padding(
                                     padding: const EdgeInsets.all(16),
                                     child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                           SizedBox(
                                              width: 300,
                                              child: TextField(
                                                decoration: InputDecoration(
                                                  hintText: 'Tìm kiếm sản phẩm, SKU...',
                                                  prefixIcon: const Icon(Icons.search, size: 20),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                                ),
                                                onChanged: (v) => setState(() => _searchQuery = v),
                                              ),
                                           ),
                                           SegmentedButton<String>(
                                              segments: const [
                                                ButtonSegment(value: 'all', label: Text('Tất cả')),
                                                ButtonSegment(value: 'low', label: Text('Sắp hết')),
                                                ButtonSegment(value: 'ok', label: Text('Đủ hàng')),
                                              ],
                                              selected: {_filterStatus},
                                              onSelectionChanged: (set) => setState(() => _filterStatus = set.first),
                                           ),
                                        ],
                                     ),
                                  ),
                                  const Divider(height: 1),
                                  
                                          if (filtered.isEmpty) 
                                    const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Không có dữ liệu', style: TextStyle(color: AppColors.textHint))))
                                  else 
                                     LayoutBuilder(
                                        builder: (context, constraints) {
                                          return SingleChildScrollView(
                                             scrollDirection: Axis.horizontal,
                                             child: ConstrainedBox(
                                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                                child: DataTable(
                                                   showCheckboxColumn: false,
                                                   headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                                                   columns: const [
                                                      DataColumn(label: Text('Sản phẩm', style: TextStyle(fontWeight: FontWeight.bold))),
                                                      DataColumn(label: Text('SKU', style: TextStyle(fontWeight: FontWeight.bold))),
                                                      DataColumn(label: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold))),
                                                      DataColumn(label: Text('Tồn kho', style: TextStyle(fontWeight: FontWeight.bold))),
                                                      DataColumn(label: Text('Định mức tối thiểu', style: TextStyle(fontWeight: FontWeight.bold))),
                                                      DataColumn(label: Text('Hạn sử dụng', style: TextStyle(fontWeight: FontWeight.bold))),
                                                      DataColumn(label: Text('Nhập hàng lần cuối', style: TextStyle(fontWeight: FontWeight.bold))),
                                                   ],
                                                   rows: filtered.map((item) {
                                                      final isLow = item.quantity <= item.minQuantity;
                                                      return DataRow(
                                                         cells: [
                                                            DataCell(
                                                              Row(
                                                                children: [
                                                                  const CircleAvatar(
                                                                     radius: 16,
                                                                     backgroundColor: AppColors.surfaceVariant,
                                                                     child: Icon(Icons.inventory_2, size: 16, color: AppColors.primary),
                                                                  ),
                                                                  const SizedBox(width: 12),
                                                                  Text(item.productName ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600)),
                                                                ],
                                                              )
                                                            ),
                                                            DataCell(Text(item.productSku ?? 'N/A', style: const TextStyle(color: AppColors.textSecondary))),
                                                            DataCell(
                                                              Container(
                                                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                                 decoration: BoxDecoration(
                                                                    color: isLow ? AppColors.warningLight : AppColors.successLight,
                                                                    borderRadius: BorderRadius.circular(12)
                                                                 ),
                                                                 child: Text(isLow ? 'Sắp hết' : 'Đủ hàng', style: TextStyle(color: isLow ? AppColors.warning : AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                                                              )
                                                            ),
                                                            DataCell(
                                                              Text('${item.quantity}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isLow ? AppColors.error : AppColors.textPrimary))
                                                            ),
                                                            DataCell(Text('${item.minQuantity}', style: const TextStyle(color: AppColors.textSecondary))),
                                                            DataCell(
                                                              Text(item.expiryDate != null ? FormatUtils.formatDate(item.expiryDate!) : 'Không có', style: TextStyle(color: item.expiryDate != null && item.expiryDate!.isBefore(DateTime.now()) ? AppColors.error : AppColors.textSecondary))
                                                            ),
                                                            DataCell(Text('${item.updatedAt.day}/${item.updatedAt.month}/${item.updatedAt.year}')),
                                                         ]
                                                      );
                                                   }).toList(),
                                                ),
                                             ),
                                          );
                                        },
                                     ),
                               ]
                            )
                          )
                        ]
                     )
                  )
                )
              ]
           );
        }
      )
    );
  }
}

class _InventoryData {
  final List<WarehouseModel> warehouses;
  final List<WarehouseInventoryModel> items;
  final int? selectedWarehouseId;
  _InventoryData({required this.warehouses, required this.items, this.selectedWarehouseId});
}

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
