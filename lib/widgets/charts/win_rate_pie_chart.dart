import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../services/stats_service.dart';

/// 勝率圓餅圖
class WinRatePieChart extends StatelessWidget {
  final PlayerStats stats;

  const WinRatePieChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.wins + stats.selfDraws + stats.losses + stats.falseWins;
    if (total == 0) {
      return const Center(
        child: Text('尚無數據', style: TextStyle(color: Colors.grey)),
      );
    }

    final sections = <PieChartSectionData>[];
    final legends = <_LegendItem>[];

    void addSection(String label, int value, Color color) {
      if (value <= 0) return;
      final percent = (value / total * 100).toStringAsFixed(1);
      sections.add(PieChartSectionData(
        value: value.toDouble(),
        color: color,
        title: '$percent%',
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 60,
      ));
      legends.add(_LegendItem(label: '$label ($value)', color: color));
    }

    addSection('胡牌', stats.wins, Colors.green);
    addSection('自摸', stats.selfDraws, Colors.blue);
    addSection('放槍', stats.losses, Colors.red);
    addSection('詐胡', stats.falseWins, Colors.orange);

    // 其他局數（流局等）
    final other = stats.totalRounds - total;
    if (other > 0) {
      addSection('其他', other, Colors.grey);
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 30,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: legends.map((item) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(item.label, style: const TextStyle(fontSize: 13)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;

  _LegendItem({required this.label, required this.color});
}
