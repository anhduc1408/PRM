import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/warehouse_provider.dart';
import '../../models/product_model.dart';
import '../../models/warehouse_inventory_model.dart';
import '../../models/category_model.dart';

class WarehouseProductScreen extends StatefulWidget {
  final String? storeIdParam; // from query param
  const WarehouseProductScreen({super.key, this.storeIdParam});

  @override
  State<WarehouseProductScreen> createState() => _WarehouseProductScreenState();
}

class _WarehouseProductScreenState extends State<WarehouseProductScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  int? _filterCategoryId;
  String _filterStatus = 'active'; // 'active', 'inactive', 'all'

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInventory());
  }

  void _loadInventory() {
    final prov = context.read<WarehouseProvider>();
    final role = context.read<AuthProvider>().currentUser?.role;

    // Inventory checker can only view the main warehouse
    if (role == UserRole.inventoryChecker) {
      final main = prov.mainWarehouse();
      if (main != null) prov.loadInventoryForWarehouse(main.id);
      return;
    }

    // Load inventory for all warehouses of the selected store or main warehouse
    final storeId = int.tryParse(widget.storeIdParam ?? '');
    if (storeId != null) {
      final warehouses = prov.warehousesForStore(storeId);
      if (warehouses.isNotEmpty) {
        prov.loadInventoryForWarehouse(warehouses.first.id);
      }
    } else {
      final main = prov.mainWarehouse();
      if (main != null) prov.loadInventoryForWarehouse(main.id);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ProductModel> _filteredProducts(List<ProductModel> products) {
    var list = products;
    if (_filterStatus == 'active') {
      list = list.where((p) => p.status == 'active').toList();
    } else if (_filterStatus == 'inactive') {
      list = list.where((p) => p.status == 'inactive').toList();
    }
    
    if (_filterCategoryId != null) {
      list = list.where((p) => p.categoryId == _filterCategoryId).toList();
    }
    if (_searchCtrl.text.isNotEmpty) {
      final q = _searchCtrl.text.toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void _showProductDialog({ProductModel? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductFormSheet(
        product: product,
        categories: context.read<WarehouseProvider>().categories,
        onSave: (data) async {
          final prov = context.read<WarehouseProvider>();
          final auth = context.read<AuthProvider>();
          final storeId = auth.currentUser?.storeId;
          final wId = storeId == null 
              ? prov.mainWarehouse()?.id 
              : prov.warehousesForStore(storeId).firstOrNull?.id;

          if (product == null) {
            await prov.addProduct(
              sku: data['sku'] as String,
              name: data['name'] as String,
              categoryId: data['categoryId'] as int,
              unit: data['unit'] as String,
              costPrice: data['costPrice'] as double,
              sellingPrice: data['sellingPrice'] as double,
              emoji: data['emoji'] as String,
              barcode: data['barcode'] as String?,
              warehouseId: wId,
              expiryDate: data['expiryDate'] as DateTime?,
            );
          } else {
            await prov.updateProduct(product,
              name: data['name'] as String,
              categoryId: data['categoryId'] as int,
              unit: data['unit'] as String,
              costPrice: data['costPrice'] as double,
              sellingPrice: data['sellingPrice'] as double,
              emoji: data['emoji'] as String,
              barcode: data['barcode'] as String?,
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa sản phẩm'),
        content: Text.rich(TextSpan(children: [
          const TextSpan(text: 'Xóa '),
          TextSpan(text: product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: '? Hành động này không thể hoàn tác.'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<WarehouseProvider>().deleteProduct(product.id);
              _showSnack('Đã xóa ${product.name}', isError: true);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmToggleOff(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận tắt sản phẩm'),
        content: Text('Bạn có chắc chắn muốn ngừng hoạt động của sản phẩm "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<WarehouseProvider>().toggleProductStatus(product);
              _showSnack('Đã tắt ${product.name}', isError: true);
            },
            child: const Text('Tắt', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
    final storeId = int.tryParse(widget.storeIdParam ?? '');
    final role = context.read<AuthProvider>().currentUser?.role;

    String headerTitle = 'Tất cả sản phẩm';
    bool showHeader = false;
    
    if (role == UserRole.inventoryChecker) {
      headerTitle = 'Kho Tổng';
      showHeader = true;
    } else if (storeId != null) {
      final store = prov.stores.where((s) => s.id == storeId).firstOrNull;
      if (store != null) {
        headerTitle = store.name;
        showHeader = true;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header banner
          if (showHeader)
            Container(
              color: const Color(0xFF2D7A50).withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Icon(role == UserRole.inventoryChecker ? Icons.warehouse : Icons.store, 
                     size: 14, color: const Color(0xFF2D7A50)),
                const SizedBox(width: 6),
                Text(headerTitle, style: const TextStyle(fontSize: 13, color: Color(0xFF2D7A50), fontWeight: FontWeight.w600)),
              ]),
            ),

          // Tabs
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: const Color(0xFF2D7A50),
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: const Color(0xFF2D7A50),
              tabs: const [
                Tab(text: '📦 Hàng hóa', icon: null),
                Tab(text: '📊 Tồn kho', icon: null),
                Tab(text: '📅 Hạn dùng', icon: null),
              ],
            ),
          ),

          // Search + Filters
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Tìm sản phẩm theo tên, SKU...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _searchCtrl.clear()))
                      : null,
                ),
              ),
              if (_tabCtrl.index == 0) ...[
                const SizedBox(height: 8),
                // Filters
                Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _filterCategoryId,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tất cả danh mục')),
                          ...prov.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (v) => setState(() => _filterCategoryId = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterStatus,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Đang hoạt động')),
                          DropdownMenuItem(value: 'inactive', child: Text('Không hoạt động')),
                          DropdownMenuItem(value: 'all', child: Text('Tất cả trạng thái')),
                        ],
                        onChanged: (v) => setState(() => _filterStatus = v ?? 'active'),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ]),
        ),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ─── Tab 1: Products List ───
                prov.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildProductList(prov, storeId),

                // ─── Tab 2: Inventory ───
                _buildInventoryTab(prov, storeId),

                // ─── Tab 3: Expiry ───
                _buildExpiryTab(prov),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabCtrl.index == 1 ? FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        backgroundColor: const Color(0xFF2D7A50),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm sản phẩm', style: TextStyle(fontWeight: FontWeight.w600)),
      ) : null,
    );
  }

  Widget _buildProductList(WarehouseProvider prov, int? storeId) {
    var products = _filteredProducts(prov.products);
    if (products.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('📦', style: TextStyle(fontSize: 52)),
          SizedBox(height: 12),
          Text('Không có sản phẩm', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final product = products[i];
        
        // Find expiry status for this product across all inventory batches
        final invs = prov.inventory.where((inv) => inv.productId == product.id && inv.expiryDate != null).toList();
        
        bool hasExpired = false;
        bool hasExpiring = false;
        bool hasValid = false;
        final now = DateTime.now();
        
        for (final inv in invs) {
          final days = inv.expiryDate!.difference(now).inDays;
          if (days < 0) hasExpired = true;
          else if (days <= 30) hasExpiring = true;
          else hasValid = true;
        }
        
        String? expiryLabel;
        Color? expiryColor;
        Color? expiryBg;
        
        if (hasExpired) {
          expiryLabel = 'Có hàng hết hạn!';
          expiryColor = AppColors.error;
          expiryBg = AppColors.errorLight;
        } else if (hasExpiring) {
          expiryLabel = 'Sắp hết hạn';
          expiryColor = AppColors.warning;
          expiryBg = AppColors.warningLight;
        } else if (hasValid) {
          expiryLabel = 'Còn hạn';
          expiryColor = AppColors.success;
          expiryBg = AppColors.successLight;
        }

        return _ProductCard(
          product: product,
          expiryLabel: expiryLabel,
          expiryColor: expiryColor,
          expiryBgColor: expiryBg,
          onEdit: () => _showProductDialog(product: product),
          onDelete: () => _confirmDelete(context, product),
          onToggle: () {
            if (product.status == 'active') {
              _confirmToggleOff(context, product);
            } else {
              context.read<WarehouseProvider>().toggleProductStatus(product);
              _showSnack('Đã bật ${product.name}');
            }
          },
        );
      },
    );
  }

  Widget _buildInventoryTab(WarehouseProvider prov, int? storeId) {
    final inventory = prov.inventory;
    if (inventory.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📊', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text('Chưa có dữ liệu tồn kho', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          if (storeId != null)
            ElevatedButton(
              onPressed: _loadInventory,
              child: const Text('Tải lại'),
            ),
        ],
      ));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 100),
      itemCount: inventory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final inv = inventory[i];
        return _InventoryCard(
          inv: inv,
          onAdjust: () => _showAdjustDialog(inv),
        );
      },
    );
  }

  // ─── EXPIRY TAB ──────────────────────────────────────────────────────────
  Widget _buildExpiryTab(WarehouseProvider prov) {
    final now = DateTime.now();
    final expired = prov.expiredItems;
    final valid = prov.validItems;
    final expiring30 = prov.expiringWithin(30);

    // Tất cả items có ngày hạn, sắp xếp: hết hạn trước, sau đó sắp hết, rồi còn hạn lâu
    final allWithExpiry = [
      ...prov.inventory.where((i) => i.expiryDate != null),
    ]..sort((a, b) {
        final da = a.expiryDate!;
        final db = b.expiryDate!;
        return da.compareTo(db); // cũ nhất lên đầu
      });

    if (prov.inventory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📅', style: TextStyle(fontSize: 52)),
            SizedBox(height: 12),
            Text('Chưa có dữ liệu tồn kho',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Summary Cards ──
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              _ExpiryStatCard(
                icon: Icons.check_circle_outline,
                label: 'Còn hạn',
                count: valid.length,
                color: AppColors.success,
                bgColor: AppColors.successLight,
              ),
              const SizedBox(width: 8),
              _ExpiryStatCard(
                icon: Icons.warning_amber_rounded,
                label: 'Sắp hết hạn',
                count: expiring30.length,
                color: AppColors.warning,
                bgColor: AppColors.warningLight,
              ),
              const SizedBox(width: 8),
              _ExpiryStatCard(
                icon: Icons.cancel_outlined,
                label: 'Hết hạn',
                count: expired.length,
                color: AppColors.error,
                bgColor: AppColors.errorLight,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── List ──
        Expanded(
          child: allWithExpiry.isEmpty
              ? const Center(
                  child: Text(
                    'Không có sản phẩm có ngày hạn dùng',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: allWithExpiry.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ExpiryCard(
                    inv: allWithExpiry[i],
                    now: now,
                    onEditExpiry: () => _showEditExpiryDialog(allWithExpiry[i]),
                  ),
                ),
        ),
      ],
    );
  }

  void _showEditExpiryDialog(WarehouseInventoryModel inv) async {
    DateTime selectedDate = inv.expiryDate ?? DateTime.now().add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Chọn ngày hết hạn',
      confirmText: 'Lưu',
      cancelText: 'Hủy',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: const Color(0xFF2D7A50),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      await context.read<WarehouseProvider>().updateExpiryDate(
            inv.warehouseId, inv.productId, picked);
      _showSnack('Đã cập nhật ngày hết hạn: ${_fmtDate(picked)}');
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _showAdjustDialog(WarehouseInventoryModel inv) {
    final ctrl = TextEditingController(text: '${inv.quantity}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(inv.productName ?? 'Sản phẩm', style: const TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Kho: ${inv.warehouseName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số lượng mới', suffixText: 'đơn vị'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D7A50)),
            onPressed: () {
              final qty = int.tryParse(ctrl.text.trim());
              if (qty != null && qty >= 0) {
                Navigator.pop(ctx);
                context.read<WarehouseProvider>()
                    .adjustInventory(inv.warehouseId, inv.productId, qty);
                _showSnack('Đã cập nhật tồn kho ${inv.productName}');
              }
            },
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── WIDGETS ─────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2D7A50) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final String? expiryLabel;
  final Color? expiryColor, expiryBgColor;
  final VoidCallback onEdit, onDelete, onToggle;
  const _ProductCard({
    required this.product, 
    this.expiryLabel, this.expiryColor, this.expiryBgColor, 
    required this.onEdit, required this.onDelete, required this.onToggle
  });

  @override
  Widget build(BuildContext context) {
    final isActive = product.status == 'active';
    return Container(
      decoration: BoxDecoration(
        color: isActive ? AppColors.surface : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: isActive ? null : Border.all(color: AppColors.border),
        boxShadow: isActive
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          // Emoji
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2D7A50).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(product.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          
          // Left Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14,
                      color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                    ), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('SKU: ${product.sku}  ·  ${product.unit}  ·  Danh mục: ${product.categoryName ?? ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                const SizedBox(height: 5),
                Row(children: [
                  Text('Bán: ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(_fmtCurrency(product.sellingPrice),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2D7A50))),
                  const SizedBox(width: 10),
                  Text('Vốn: ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(_fmtCurrency(product.costPrice),
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                ]),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Right Badges & Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badges
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.successLight : AppColors.errorLight,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isActive ? Icons.check_circle_outline : Icons.cancel_outlined, 
                             size: 11, color: isActive ? AppColors.success : AppColors.error),
                        const SizedBox(width: 4),
                        Text(isActive ? 'Đang hoạt động' : 'Không hoạt động', 
                             style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? AppColors.success : AppColors.error)),
                      ],
                    ),
                  ),
                  if (expiryLabel != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: expiryBgColor, borderRadius: BorderRadius.circular(5)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 10, color: expiryColor),
                          const SizedBox(width: 4),
                          Text(expiryLabel!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: expiryColor)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              // Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Btn(label: isActive ? 'Tắt' : 'Bật', color: isActive ? AppColors.warning : AppColors.success, onTap: onToggle),
                  const SizedBox(width: 6),
                  _Btn(label: 'Sửa', color: AppColors.info, onTap: onEdit),
                  const SizedBox(width: 6),
                  _Btn(label: 'Xóa', color: AppColors.error, onTap: onDelete),
                ],
              ),
            ],
          ),
        ]),
      ),
    );
  }

  String _fmtCurrency(double v) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '${b}đ';
  }
}

class _Btn extends StatelessWidget {
  final String label; final Color color; final VoidCallback onTap;
  const _Btn({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ),
  );
}

class _InventoryCard extends StatelessWidget {
  final WarehouseInventoryModel inv;
  final VoidCallback onAdjust;
  const _InventoryCard({required this.inv, required this.onAdjust});

  @override
  Widget build(BuildContext context) {
    final low = inv.isLowStock;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: low ? Border.all(color: AppColors.warning, width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: low ? AppColors.warningLight : AppColors.successLight,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.inventory_2, color: low ? AppColors.warning : AppColors.success, size: 20),
        ),
        title: Text(inv.productName ?? 'Sản phẩm #${inv.productId}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(inv.productSku ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${inv.quantity}',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: low ? AppColors.warning : AppColors.textPrimary,
                )),
            Text('min: ${inv.minQuantity}', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
          ]),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAdjust,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2D7A50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune, size: 16, color: Color(0xFF2D7A50)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── PRODUCT FORM SHEET ───────────────────────────────────────────────────────

class _ProductFormSheet extends StatefulWidget {
  final ProductModel? product;
  final List<CategoryModel> categories;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _ProductFormSheet({this.product, required this.categories, required this.onSave});

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _skuCtrl, _costCtrl, _sellCtrl, _unitCtrl, _emojiCtrl, _barcodeCtrl;
  int? _categoryId;
  DateTime? _expiryDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl    = TextEditingController(text: p?.name ?? '');
    _skuCtrl     = TextEditingController(text: p?.sku ?? context.read<WarehouseProvider>().nextSku());
    _costCtrl    = TextEditingController(text: p != null ? p.costPrice.toStringAsFixed(0) : '');
    _sellCtrl    = TextEditingController(text: p != null ? p.sellingPrice.toStringAsFixed(0) : '');
    _unitCtrl    = TextEditingController(text: p?.unit ?? 'cup');
    _emojiCtrl   = TextEditingController(text: p?.emoji ?? '🧋');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _categoryId  = p?.categoryId ?? (widget.categories.isNotEmpty ? widget.categories.first.id : null);
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _skuCtrl, _costCtrl, _sellCtrl, _unitCtrl, _emojiCtrl, _barcodeCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSave({
      'sku': _skuCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'categoryId': _categoryId,
      'unit': _unitCtrl.text.trim().isEmpty ? 'cup' : _unitCtrl.text.trim(),
      'costPrice': double.tryParse(_costCtrl.text.trim()) ?? 0.0,
      'sellingPrice': double.tryParse(_sellCtrl.text.trim()) ?? 0.0,
      'emoji': _emojiCtrl.text.trim().isEmpty ? '🧋' : _emojiCtrl.text.trim(),
      'barcode': _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      'expiryDate': _expiryDate,
    });
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.product == null ? 'Đã thêm sản phẩm!' : 'Đã cập nhật sản phẩm!'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              Text(isEdit ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm mới',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                controller: ctrl,
                padding: EdgeInsets.only(left: 20, right: 20, top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 100),
                children: [
                  // Emoji + Name
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 72, child: TextFormField(
                      controller: _emojiCtrl,
                      style: const TextStyle(fontSize: 28),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(labelText: 'Icon', counterText: '', isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8)),
                      maxLength: 2,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Tên sản phẩm *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên sản phẩm' : null,
                    )),
                  ]),
                  const SizedBox(height: 12),
                  // SKU + Barcode
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: _skuCtrl,
                      enabled: !isEdit,
                      decoration: const InputDecoration(labelText: 'SKU *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập SKU' : null,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(
                      controller: _barcodeCtrl,
                      decoration: const InputDecoration(labelText: 'Barcode'),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  // Category
                  DropdownButtonFormField<int>(
                    value: _categoryId,
                    decoration: const InputDecoration(labelText: 'Danh mục *'),
                    items: widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) => v == null ? 'Chọn danh mục' : null,
                  ),
                  const SizedBox(height: 12),
                  // Expiry
                  if (!isEdit) ...[
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now().add(const Duration(days: 1)),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _expiryDate = picked);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400, width: 1), 
                          borderRadius: BorderRadius.circular(4)
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_expiryDate == null 
                                ? 'Ngày hết hạn (không bắt buộc)' 
                                : 'Hạn sử dụng: ${_expiryDate!.day.toString().padLeft(2,'0')}/${_expiryDate!.month.toString().padLeft(2,'0')}/${_expiryDate!.year}',
                                style: TextStyle(
                                  color: _expiryDate == null ? AppColors.textHint : AppColors.textPrimary,
                                  fontSize: 16
                                )),
                            const Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Price row
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Giá vốn (đ)', prefixText: '₫ '),
                      validator: (v) => (v == null || double.tryParse(v.trim()) == null) ? 'Nhập giá' : null,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(
                      controller: _sellCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Giá bán (đ) *', prefixText: '₫ '),
                      validator: (v) => (v == null || double.tryParse(v.trim()) == null) ? 'Nhập giá' : null,
                    )),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(labelText: 'Đơn vị', hintText: 'cup, cây, ly, cái...'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7A50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Lưu thay đổi' : 'Thêm sản phẩm',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── EXPIRY STAT CARD ─────────────────────────────────────────────────────────

class _ExpiryStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final Color bgColor;
  const _ExpiryStatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EXPIRY CARD ──────────────────────────────────────────────────────────────

class _ExpiryCard extends StatelessWidget {
  final WarehouseInventoryModel inv;
  final DateTime now;
  final VoidCallback onEditExpiry;
  const _ExpiryCard({required this.inv, required this.now, required this.onEditExpiry});

  @override
  Widget build(BuildContext context) {
    final expiry = inv.expiryDate;
    final isExpired = expiry != null && expiry.isBefore(now);
    final daysLeft = expiry?.difference(now).inDays;
    final isExpiring = !isExpired && daysLeft != null && daysLeft <= 30;

    final Color cardColor;
    final Color accentColor;
    final Color badgeBg;
    final IconData statusIcon;

    if (isExpired) {
      cardColor = AppColors.errorLight;
      accentColor = AppColors.error;
      badgeBg = AppColors.errorLight;
      statusIcon = Icons.cancel_outlined;
    } else if (isExpiring) {
      cardColor = AppColors.warningLight;
      accentColor = AppColors.warning;
      badgeBg = AppColors.warningLight;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      cardColor = AppColors.surface;
      accentColor = AppColors.success;
      badgeBg = AppColors.successLight;
      statusIcon = Icons.check_circle_outline;
    }

    final expiryStr = expiry != null
        ? '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}'
        : '--';

    final daysStr = daysLeft == null
        ? ''
        : isExpired
            ? 'Quá hạn ${(-daysLeft)} ngày'
            : daysLeft == 0
                ? 'Hết hạn hôm nay!'
                : 'Còn $daysLeft ngày';

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 5, offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status icon circle
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: Icon(statusIcon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 12),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inv.productName ?? 'Sản phẩm #${inv.productId}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    inv.productSku ?? '',
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.calendar_today, size: 11, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      'HSD: $expiryStr',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                    if (daysStr.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          daysStr,
                          style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right side: qty + edit button
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${inv.quantity}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  'đơn vị',
                  style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onEditExpiry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D7A50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.edit_calendar, size: 12, color: Color(0xFF2D7A50)),
                      SizedBox(width: 3),
                      Text('Sửa', style: TextStyle(fontSize: 11, color: Color(0xFF2D7A50), fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
