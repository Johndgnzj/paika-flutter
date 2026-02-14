import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 台數分布長條圖
class TaiDistributionChart extends StatelessWidget {
  final Map<int, int> taiDistribution;

  const TaiDistributionChart({super.key, required this.taiDistribution});

  @override
  Widget build(BuildContext context) {
    if (taiDistribution.isEmpty) {
      return const Center(
        child: Text('尚無數據', style: TextStyle(color: Colors.grey)),
      );
    }

    final sortedKeys = taiDistribution.keys.toList()..sort();
    final maxCount = taiDistribution.values.reduce((a, b) => a > b ? a : b);

    // 找出最常出現的台數
    int mostCommonTai = sortedKeys.first;
    for (final key in sortedKeys) {
      if (taiDistribution[key]! > taiDistribution[mostCommonTai]!) {
        mostCommonTai = key;
      }
    }

    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCount.toDouble() * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outlineVariant,
              strokeWidth: 0.5,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value == value.toInt().toDouble()) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sortedKeys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${sortedKeys[index]}台',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: sortedKeys.asMap().entries.map((entry) {
            final index = entry.key;
            final tai = entry.value;
            final count = taiDistribution[tai]!;
            final isHighest = tai == mostCommonTai;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: count.toDouble(),
                  color: isHighest ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.5),
                  width: sortedKeys.length > 10 ? 12 : 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final tai = sortedKeys[group.x];
                return BarTooltipItem(
                  '$tai台：${rod.toY.toInt()}次',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
