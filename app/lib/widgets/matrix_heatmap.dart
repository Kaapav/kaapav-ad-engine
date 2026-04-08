import 'package:flutter/material.dart';
import 'package:kaapav_ad_engine/core/theme.dart';
import 'package:kaapav_ad_engine/widgets/glass_card.dart';

typedef HeatmapCellTap = void Function(int row, int col, double value);

class MatrixHeatmap extends StatelessWidget {
  final List<String> rows; // audiences
  final List<String> cols; // creatives
  final List<List<double>> values; // 0-100
  final double cellSize;
  final HeatmapCellTap? onCellTap;

  const MatrixHeatmap({
    super.key,
    required this.rows,
    required this.cols,
    required this.values,
    this.cellSize = 36,
    this.onCellTap,
  });

  Color _cellColor(double v) {
    final s = v.clamp(0, 100);
    if (s >= 80) return C.success;
    if (s >= 60) return C.warning;
    return C.error;
  }

  @override
  Widget build(BuildContext context) {
    final safeRowCount = rows.length;
    final safeColCount = cols.length;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Creative × Audience Heatmap',
            style: TextStyle(
              color: C.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Green = strong • Amber = moderate • Red = weak',
            style: TextStyle(color: C.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 140, height: cellSize),
                    for (int r = 0; r < safeRowCount; r++)
                      SizedBox(
                        width: 140,
                        height: cellSize,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            rows[r],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: C.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (int c = 0; c < safeColCount; c++)
                          Container(
                            width: cellSize,
                            height: cellSize,
                            margin: const EdgeInsets.only(right: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: C.glassWhite,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: C.glassBorder),
                            ),
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Text(
                                cols[c],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: C.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (int r = 0; r < safeRowCount; r++)
                      Row(
                        children: [
                          for (int c = 0; c < safeColCount; c++) _cell(r, c),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(int r, int c) {
    final row = values.length > r ? values[r] : const <double>[];
    final v = row.length > c ? row[c] : 0.0;
    final color = _cellColor(v);

    return GestureDetector(
      onTap: onCellTap == null ? null : () => onCellTap!(r, c, v),
      child: Container(
        width: cellSize,
        height: cellSize,
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          v.clamp(0, 100).toStringAsFixed(0),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}