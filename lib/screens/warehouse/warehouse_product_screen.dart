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
    _tabCtrl = TabController(length: 2, vsync: this);
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
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        backgroundColor: const Color(0xFF2D7A50),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm sản phẩm', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
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
      itemBuilder: (_, i) => _ProductCard(
        product: products[i],
        onEdit: () => _showProductDialog(product: products[i]),
        onDelete: () => _confirmDelete(context, products[i]),
        onToggle: () {
          if (products[i].status == 'active') {
            _confirmToggleOff(context, products[i]);
          } else {
            context.read<WarehouseProvider>().toggleProductStatus(products[i]);
            _showSnack('Đã bật ${products[i].name}');
          }
        },
      ),
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
  final VoidCallback onEdit, onDelete, onToggle;
  const _ProductCard({required this.product, required this.onEdit, required this.onDelete, required this.onToggle});

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
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2D7A50).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(product.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                      ), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (!isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(5)),
                      child: const Text('Không hoạt động', style: TextStyle(fontSize: 10, color: AppColors.error)),
                    ),
                ]),
                const SizedBox(height: 2),
                Text('SKU: ${product.sku}  ·  ${product.unit}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                const SizedBox(height: 3),
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
            )),
          ]),
        ),
        // Action row
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(children: [
            Text(product.categoryName ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            const Spacer(),
            _Btn(label: isActive ? 'Tắt' : 'Bật', color: isActive ? AppColors.warning : AppColors.success, onTap: onToggle),
            const SizedBox(width: 6),
            _Btn(label: 'Sửa', color: AppColors.info, onTap: onEdit),
            const SizedBox(width: 6),
            _Btn(label: 'Xóa', color: AppColors.error, onTap: onDelete),
          ]),
        ),
      ]),
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
