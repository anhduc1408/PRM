import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/warehouse_provider.dart';
import '../../models/store_model.dart';
import '../../models/warehouse_model.dart';

class WarehouseStoreListScreen extends StatelessWidget {
  const WarehouseStoreListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<WarehouseProvider>();

    if (prov.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prov.error != null) {
      return Center(child: Text('Lỗi: ${prov.error}'));
    }

    final stores = prov.stores;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary header
        _SummaryRow(
          totalStores: stores.length,
          totalWarehouses: prov.warehouses.length,
          totalProducts: prov.products.length,
          lowStock: prov.lowStockItems.length,
        ),
        const SizedBox(height: 16),
        const Text('Danh sách cửa hàng',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ...stores.map((store) {
          final storeWarehouses = prov.warehousesForStore(store.id);
          return _StoreCard(
            store: store,
            warehouses: storeWarehouses,
            onTap: () {
              if (storeWarehouses.isEmpty) return;
              // Load inventory for the first warehouse and navigate to products
              context.go('/warehouse/products?storeId=${store.id}');
            },
          );
        }),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int totalStores, totalWarehouses, totalProducts, lowStock;
  const _SummaryRow({
    required this.totalStores, required this.totalWarehouses,
    required this.totalProducts, required this.lowStock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A4731), Color(0xFF2D7A50)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tổng quan hệ thống',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatItem(label: 'Cửa hàng', value: '$totalStores', icon: Icons.store),
              _StatItem(label: 'Kho', value: '$totalWarehouses', icon: Icons.warehouse),
              _StatItem(label: 'Sản phẩm', value: '$totalProducts', icon: Icons.inventory_2),
              _StatItem(
                label: 'Sắp hết', value: '$lowStock', icon: Icons.warning_amber,
                valueColor: lowStock > 0 ? const Color(0xFFFFD700) : Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? valueColor;
  const _StatItem({required this.label, required this.value, required this.icon, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 18),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
      ]),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final StoreModel store;
  final List<WarehouseModel> warehouses;
  final VoidCallback onTap;
  const _StoreCard({required this.store, required this.warehouses, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = store.status == 'active';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF2D7A50).withValues(alpha: 0.1)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.store, color: isActive ? const Color(0xFF2D7A50) : AppColors.textHint, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(store.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.successLight : AppColors.errorLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isActive ? 'Hoạt động' : 'Tạm đóng',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: isActive ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 2),
                        Text(store.code, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                        if (store.address != null)
                          Text(store.address!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Warehouses chips
            if (warehouses.isNotEmpty)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.warehouse_outlined, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        warehouses.map((w) => w.name).join(' · '),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Text('Xem hàng hóa →',
                        style: TextStyle(fontSize: 12, color: Color(0xFF2D7A50), fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: const Text('Chưa có kho được gán',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }
}
