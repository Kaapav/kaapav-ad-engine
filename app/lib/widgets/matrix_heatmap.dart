import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/creative_match.dart';

/// Audience × Creative matrix heatmap
/// Green = strong match, Amber = moderate, Red = weak/stop
class MatrixHeatmap extends StatelessWidget {
  final List<CreativeMatch> matches;
  final double cellSize;

  const MatrixHeatmap({
    super.key,
    required this.matches,
    this.cellSize = 52,
  });

  // ── Build unique sorted labels ──────────────────────────────
  List<String> get _audiences {
    final seen = <String>{};
    return matches
        .map((m) => m.audienceKey ?? 'Unknown')
        .where(seen.add)
        .toList();
  }

  List<String> get _creatives {
    final seen = <String>{};
    return matches.map((m) => m.creativeName).where(seen.add).toList();
  }

  // ── Lookup match score for a cell ──────────────────────────
  double? _score(String creative, String audience) {
    try {
      return matches
          .firstWhere(
            (m) =>
                m.creativeName == creative &&
                (m.audienceKey ?? 'Unknown') == audience,
          )
          .matchScore;
    } catch (_) {
      return null;
    }
  }

  Color _cellColor(double? score) {
    if (score == null) return C.glassWhite;
    if (score >= 80) return C.success.withValues(alpha: 0.22);
    if (score >= 60) return C.primary.withValues(alpha: 0.18);
    if (score >= 40) return C.warning.withValues(alpha: 0.18);
    return C.error.withValues(alpha: 0.18);
  }

  Color _textColor(double? score) {
    if (score == null) return C.textMuted;
    if (score >= 80) return C.success;
    if (score >= 60) return C.primary;
    if (score >= 40) return C.warning;
    return C.error;
  }

  @override
  Widget build(BuildContext context) {
    final audiences = _audiences;
    final creatives = _creatives;

    if (audiences.isEmpty || creatives.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text(
            'No matrix data yet — run recompute',
            style: TextStyle(color: C.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row (audience names) ───────────────────
          Row(
            children: [
              // Empty corner cell
              SizedBox(width: 90, height: cellSize * 0.7),
              ...audiences.map(
                (a) => SizedBox(
                  width: cellSize,
                  height: cellSize * 0.7,
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        _shortLabel(a),
                        style: const TextStyle(
                          color:      C.textSecondary,
                          fontSize:   9,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Data rows (one per creative) ──────────────────
          ...creatives.map(
            (creative) => Row(
              children: [
                // Creative label
                SizedBox(
                  width:  90,
                  height: cellSize,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _shortLabel(creative),
                        style: const TextStyle(
                          color:      C.textSecondary,
                          fontSize:   10,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines:  2,
                        overflow:  TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ),

                // Score cells
                ...audiences.map((audience) {
                  final score = _score(creative, audience);
                  return _HeatCell(
                    score:     score,
                    cellSize:  cellSize,
                    cellColor: _cellColor(score),
                    textColor: _textColor(score),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Legend ────────────────────────────────────────
          Row(
            children: [
              _legendDot(C.success, 'Winner (80+)'),
              const SizedBox(width: 14),
              _legendDot(C.primary, 'Good (60–79)'),
              const SizedBox(width: 14),
              _legendDot(C.warning, 'Weak (40–59)'),
              const SizedBox(width: 14),
              _legendDot(C.error,   'Stop (<40)'),
            ],
          ),
        ],
      ),
    );
  }

  String _shortLabel(String s) {
    // Remove "campaign:" prefix for display
    final clean = s.replaceFirst('campaign:', '');
    // Truncate to 14 chars
    return clean.length > 14 ? '${clean.substring(0, 12)}…' : clean;
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width:  8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color:    C.textMuted,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  final double?  score;
  final double   cellSize;
  final Color    cellColor;
  final Color    textColor;

  const _HeatCell({
    required this.score,
    required this.cellSize,
    required this.cellColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  cellSize,
      height: cellSize,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color:        cellColor,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: C.glassBorder),
      ),
      child: Center(
        child: score != null
            ? Text(
                score!.toStringAsFixed(0),
                style: TextStyle(
                  color:      textColor,
                  fontSize:   12,
                  fontWeight: FontWeight.w900,
                ),
              )
            : const Text(
                '—',
                style: TextStyle(
                  color:    C.textMuted,
                  fontSize: 10,
                ),
              ),
      ),
    );
  }
}