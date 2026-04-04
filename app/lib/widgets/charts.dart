//lib/widgets/charts.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';

// ═══ ROAS LINE CHART ═══
class RoasLineChart extends StatelessWidget {
  final List<double> data;
  final double height;
  final Color? color;

  const RoasLineChart({super.key, required this.data, this.height = 140, this.color});

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return SizedBox(height: height);
    final c = color ?? C.primary;
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: C.glassBorder,
              strokeWidth: 0.5,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: c,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.withValues(alpha: 0.2),
                    c.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => C.bgCard,
              tooltipBorder: const BorderSide(color: C.glassTurqBorder),
              tooltipRoundedRadius: 10,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(1)}x',
                        TextStyle(
                          color: c,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }
}

// ═══ SPARKLINE (tiny inline chart) ═══
class Sparkline extends StatelessWidget {
  final List<double> data;
  final double width;
  final double height;
  final Color? color;

  const Sparkline({super.key, required this.data, this.width = 50, this.height = 20, this.color});

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return SizedBox(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparkPainter(data: data, color: color ?? C.primary)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparkPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = max - min;
    final yScale = range > 0 ? size.height / range : 1.0;
    final xStep = size.width / (data.length - 1);

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i * xStep;
      final y = size.height - ((data[i] - min) * yScale);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ═══ DONUT CHART ═══
class DonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final double size;
  final Widget? center;

  const DonutChart({super.key, required this.segments, this.size = 120, this.center});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: size / 2 - 20,
              startDegreeOffset: -90,
              sections: segments
                  .map((s) => PieChartSectionData(
                        value: s.value,
                        color: s.color,
                        radius: 18,
                        showTitle: false,
                      ))
                  .toList(),
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class DonutSegment {
  final double value;
  final Color color;
  final String label;
  const DonutSegment({required this.value, required this.color, required this.label});
}