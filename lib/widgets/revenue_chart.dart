import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants/app_colors.dart';
import '../data/database_service.dart';
import '../core/utils/format_utils.dart';

class RevenueChart extends StatelessWidget {
  final List<ChartEntry> data;
  final int days;

  const RevenueChart({super.key, required this.data, required this.days});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.every((e) => e.value == 0)) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('Chưa có dữ liệu doanh thu', style: TextStyle(color: AppColors.textHint)),
      );
    }

    final maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    
    // Adjust visual density based on how many bars we have
    int showEvery = 1;
    double barWidth = 18;
    if (data.length > 20) {
      showEvery = 5;
      barWidth = 6;
    } else if (data.length > 10) {
      showEvery = 2;
      barWidth = 10;
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.textPrimary,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                FormatUtils.formatCurrency(rod.toY),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= data.length) return const SizedBox();
                  if (idx % showEvery != 0) return const SizedBox();
                  
                  // For very long labels like '2024-03-12', take just '12/03'
                  String label = data[idx].label;
                  if (label.length == 10 && label.contains('-')) { // YYYY-MM-DD
                    final parts = label.split('-');
                    label = '${parts[2]}/${parts[1]}';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox();
                  return Text(_formatY(value), style: const TextStyle(fontSize: 9, color: AppColors.textSecondary));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          barGroups: List.generate(data.length, (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i].value,
                gradient: const LinearGradient(
                  colors: [AppColors.primaryLight, AppColors.primary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                width: barWidth,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          )),
        ),
      ),
    );
  }

  String _formatY(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }
}
