import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/format_utils.dart';
import '../../data/database_service.dart';
import '../../models/product_model.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedCategory;
  late Future<List<ProductModel>> _productsFuture;

  @override
  void initState() {
    super.initState();
    // Assign directly — no setState in initState
    _productsFuture = DatabaseService.instance.getProductsActive();
  }

  void _load() {
    final f = DatabaseService.instance.getProductsActive();
    if (mounted) setState(() => _productsFuture = f);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<ProductModel>>(
        future: _productsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          var filtered = all;
          if (_selectedCategory != null) filtered = filtered.where((p) => p.categoryName == _selectedCategory).toList();
          if (_searchCtrl.text.isNotEmpty) {
            final q = _searchCtrl.text.toLowerCase();
            filtered = filtered.where((p) => p.name.toLowerCase().contains(q)).toList();
          }

          return Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(hintText: 'Tìm sản phẩm...', prefixIcon: Icon(Icons.search), isDense: true),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _CategoryChip(label: 'Tất cả', isSelected: _selectedCategory == null, onTap: () => setState(() => _selectedCategory = null)),
                        // Dynamic category chips from loaded products
                        ...all.map((p) => p.categoryName ?? '').toSet()
                            .map((cat) => _CategoryChip(
                              label: cat,
                              isSelected: _selectedCategory == cat,
                              onTap: () => setState(() => _selectedCategory = _selectedCategory == cat ? null : cat),
                            )),
                      ]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final cols = constraints.maxWidth > 900 ? 5 : constraints.maxWidth > 600 ? 4 : 3;
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _ProductCard(product: filtered[i]),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label; final bool isSelected; final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  const _ProductCard({required this.product});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: Text(product.emoji, style: const TextStyle(fontSize: 32)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(product.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(FormatUtils.formatCurrency(product.price), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(6)),
          child: Text(product.categoryName ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ),
      ]),
    );
  }
}
