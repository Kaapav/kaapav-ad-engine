import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';

class SpendRevenueData {
  final String label;
  final double spend;
  final double revenue;
  const SpendRevenueData({required this.label, required this.spend, required this.revenue});
}

class SpendRevenueChart extends StatelessWidget {
  final List<SpendRevenueData> data;
  const SpendRevenueChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Spend vs Revenue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              _Dot(color: KaapavColors.kaapav500, label: 'Spend'),
              const SizedBox(width: 12),
              _Dot(color: KaapavColors.success, label: 'Revenue'),
            ]),
            const SizedBox(height: 24),
            SizedBox(height: 200, child: LineChart(LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.04), strokeWidth: 1)),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    return Padding(padding: const EdgeInsets.only(top: 8),
                      child: Text(data[i].label, style: const TextStyle(fontSize: 10, color: KaapavColors.dark500)));
                  })),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42,
                  getTitlesWidget: (v, m) => Text(Fmt.currencyShort(v), style: const TextStyle(fontSize: 10, color: KaapavColors.dark500)))),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => KaapavColors.dark800.withOpacity(0.9),
                tooltipRoundedRadius: 12,
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(Fmt.currency(s.y),
                  TextStyle(color: s.barIndex == 0 ? KaapavColors.kaapav400 : KaapavColors.success, fontWeight: FontWeight.w600, fontSize: 12))).toList())),
              lineBarsData: [
                _line(data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.spend)).toList(), KaapavColors.kaapav500),
                _line(data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.revenue)).toList(), KaapavColors.success),
              ],
            ), duration: const Duration(milliseconds: 400))),
          ]))));
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots, isCurved: true, curveSmoothness: 0.3, color: color, barWidth: 2.5, isStrokeCapRound: true,
    dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 3, color: color, strokeWidth: 2, strokeColor: KaapavColors.dark950)),
    belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [color.withOpacity(0.15), color.withOpacity(0.0)])));
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)])),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: KaapavColors.dark400, fontWeight: FontWeight.w500)),
    ]);
  }
}
