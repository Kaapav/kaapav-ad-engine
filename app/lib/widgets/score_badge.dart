import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Universal score badge with color banding
/// Uses project color constants from C class
class ScoreBadge extends StatelessWidget {
  final double score;     // 0–100
  final double size;
  final bool   showLabel;

  const ScoreBadge({
    super.key,
    required this.score,
    this.size      = 48,
    this.showLabel = true,
  });

  Color get _color {
    if (score >= 80) return C.success;
    if (score >= 65) return C.primary;
    if (score >= 45) return C.warning;
    return C.error;
  }

  String get _label {
    if (score >= 80) return 'Strong';
    if (score >= 65) return 'Good';
    if (score >= 45) return 'Watch';
    return 'Weak';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width:  size,
          height: size,
          decoration: BoxDecoration(
            color:        _color.withValues(alpha: 0.12),
            shape:        BoxShape.circle,
            border:       Border.all(
              color: _color.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              score.toStringAsFixed(0),
              style: TextStyle(
                color:      _color,
                fontSize:   size * 0.28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            _label,
            style: TextStyle(
              color:      _color,
              fontSize:   10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

/// Horizontal score bar with animated fill
class ScoreBar extends StatelessWidget {
  final double score;   // 0–100
  final double height;
  final String? label;

  const ScoreBar({
    super.key,
    required this.score,
    this.height = 8,
    this.label,
  });

  Color get _color {
    if (score >= 80) return C.success;
    if (score >= 65) return C.primary;
    if (score >= 45) return C.warning;
    return C.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label!,
                style: const TextStyle(
                  color:    C.textMuted,
                  fontSize: 10,
                ),
              ),
              Text(
                '${score.toStringAsFixed(0)}/100',
                style: TextStyle(
                  color:      _color,
                  fontSize:   10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        TweenAnimationBuilder<double>(
          tween:    Tween(begin: 0, end: (score / 100).clamp(0, 1)),
          duration: const Duration(milliseconds: 600),
          curve:    Curves.easeOutCubic,
          builder:  (_, v, __) => ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: height,
                  color:  C.glassWhite,
                ),
                FractionallySizedBox(
                  widthFactor: v,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _color,
                          _color.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}