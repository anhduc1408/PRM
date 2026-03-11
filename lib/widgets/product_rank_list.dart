import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/format_utils.dart';

class ProductRankList extends StatelessWidget {
  final List<ProductSaleModel> products;
  final int maxShow;

  const ProductRankList({
    super.key,
    required this.products,
    this.maxShow = 5,
  });

  @override
  Widget build(BuildContext context) {
    final shown = products.take(maxShow).toList();
    if (shown.isEmpty) {
      return const Center(
        child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.textHint)),
      );
    }
    return Column(
      children: List.generate(shown.length, (i) {
        final product = shown[i];
        return _buildRow(i, product);
      }),
    );
  }

  Widget _buildRow(int index, ProductSaleModel product) {
    final rankColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final rankColor = index < 3 ? rankColors[index] : AppColors.textHint;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: index == 0
            ? const Color(0xFFFFF8E1)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: index == 0
            ? Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              product.productName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${FormatUtils.formatNumber(product.quantity)} ly',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
              Text(
                FormatUtils.formatCurrency(product.totalRevenue),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
