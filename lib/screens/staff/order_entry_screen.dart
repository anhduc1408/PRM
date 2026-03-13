import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';

class OrderEntryScreen extends StatefulWidget {
  const OrderEntryScreen({super.key});
  @override
  State<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends State<OrderEntryScreen> {
  final Map<int, int> _cart = {}; // productId -> qty
  String _paymentMethod = 'cash';
  bool _orderSuccess = false;
  late Future<List<ProductModel>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = DatabaseService.instance.getProductsActive();
  }

  @override
  Widget build(BuildContext context) {
    if (_orderSuccess) return _buildSuccessView();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<ProductModel>>(
        future: _productsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final products = snap.data ?? [];
          final cartItems = _cart.entries.where((e) => e.value > 0).map((e) => (
            product: products.firstWhere((p) => p.id == e.key),
            qty: e.value,
          )).toList();
          final total = cartItems.fold<double>(0, (s, i) => s + i.product.sellingPrice * i.qty);
          return LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            if (isWide) {
              return Row(children: [
                Expanded(flex: 3, child: _buildProductGrid(products)),
                Container(width: 320, color: AppColors.surface, child: _buildCartPanel(cartItems, total, products)),
              ]);
            }
            return Column(children: [
              Expanded(child: _buildProductGrid(products)),
              _buildCartPanel(cartItems, total, products),
            ]);
          });
        },
      ),
    );
  }

  Widget _buildProductGrid(List<ProductModel> products) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 900 ? 5 : constraints.maxWidth > 600 ? 4 : 3;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            const Text('Chọn sản phẩm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('${_cart.values.fold(0, (s, v) => s + v)} sp', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        Expanded(child: GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9),
          itemCount: products.length,
          itemBuilder: (context, i) {
           final p = products[i]; final qty = _cart[p.id] ?? 0;
            return _OrderProductCard(product: p, qty: qty, onAdd: () => setState(() => _cart[p.id] = qty + 1), onRemove: () => setState(() { if (qty > 0) _cart[p.id] = qty - 1; }));
          },
        )),
      ]);
    });
  }

  Widget _buildCartPanel(List<({ProductModel product, int qty})> cartItems, double total, List<ProductModel> products) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: const Row(children: [Icon(Icons.receipt_long, color: Colors.white, size: 18), SizedBox(width: 8), Text('Đơn hàng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))]),
        ),
        Expanded(child: cartItems.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('🛒', style: TextStyle(fontSize: 40)), SizedBox(height: 8), Text('Chưa có sản phẩm', style: TextStyle(color: AppColors.textHint))]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: cartItems.length,
              itemBuilder: (ctx, i) {
                final item = cartItems[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Text(item.product.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.product.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(FormatUtils.formatCurrency(item.product.price), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ])),
                    Text('×${item.qty}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const SizedBox(width: 6),
                    Text(FormatUtils.formatCurrency(item.product.price * item.qty), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                );
              },
            )),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Thanh toán:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              _PayChip(label: 'Tiền mặt', icon: Icons.payments, selected: _paymentMethod == 'cash', onTap: () => setState(() => _paymentMethod = 'cash')),
              const SizedBox(width: 8),
              _PayChip(label: 'Chuyển khoản', icon: Icons.account_balance, selected: _paymentMethod == 'transfer', onTap: () => setState(() => _paymentMethod = 'transfer')),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Tổng cộng:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(FormatUtils.formatCurrency(total), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18)),
              ]),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: cartItems.isEmpty ? null : () => _submitOrder(products),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Xác nhận đơn'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 6),
            OutlinedButton(onPressed: cartItems.isEmpty ? null : () => setState(() => _cart.clear()), child: const Text('Xóa đơn')),
          ]),
        ),
      ]),
    );
  }

  Future<void> _submitOrder(List<ProductModel> products) async {
    final auth = context.read<AuthProvider>();
    final storeId = auth.currentUser?.storeId ?? 1;
    final now = DateTime.now();
    final items = _cart.entries.where((e) => e.value > 0).map((e) {
      final p = products.firstWhere((pr) => pr.id == e.key);
      return SalesOrderItemModel(
        id: 0, salesOrderId: 0, productId: p.id,
        quantity: e.value, unitPrice: p.sellingPrice,
        lineTotal: p.sellingPrice * e.value, productName: p.name,
      );
    }).toList();
    final total = items.fold<double>(0, (s, i) => s + i.lineTotal);
    final order = SalesOrderModel(
      id: 0,
      orderNo: 'ORD${now.millisecondsSinceEpoch}',
      storeId: storeId,
      staffUserId: auth.currentUser?.id ?? 0,
      orderDate: now, totalAmount: total,
      finalAmount: total, paymentStatus: 'paid',
      createdAt: now, items: items,
      payments: [PaymentModel(id: 0, salesOrderId: 0, paymentMethod: _paymentMethod, amount: total, paidAt: now)],
    );
    await context.read<StoreProvider>().addOrder(order);
    if (mounted) setState(() { _cart.clear(); _orderSuccess = true; });
  }

  Widget _buildSuccessView() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.successLight, shape: BoxShape.circle),
        child: const Icon(Icons.check_circle, color: AppColors.success, size: 64)),
      const SizedBox(height: 24),
      const Text('Đơn hàng đã được xác nhận!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('Cảm ơn bạn đã phục vụ khách hàng 🧋', style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 32),
      ElevatedButton.icon(
        onPressed: () => setState(() => _orderSuccess = false),
        icon: const Icon(Icons.add), label: const Text('Tạo đơn mới'),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
      ),
    ]));
  }
}

class _PayChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PayChip({required this.label, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textSecondary)),
        ]),
      ),
    ));
  }
}
class _OrderProductCard extends StatelessWidget {
  final ProductModel product; final int qty; final VoidCallback onAdd, onRemove;
  const _OrderProductCard({required this.product, required this.qty, required this.onAdd, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    final hasQty = qty > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: hasQty ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: hasQty ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(product.emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 6),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(product.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
        const SizedBox(height: 4),
        Text(FormatUtils.formatCurrency(product.sellingPrice), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          InkWell(onTap: onRemove, borderRadius: BorderRadius.circular(6), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.remove, size: 14))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
          InkWell(onTap: onAdd, borderRadius: BorderRadius.circular(6), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.add, size: 14, color: Colors.white))),
        ]),
      ]),
    );
  }
}
