import 'package:flutter/material.dart';
import 'package:kaapav_ad_engine/core/theme.dart';

class ScoreBadge extends StatelessWidget {
  final double score; // 0-100
  final String? label;
  final double height;

  const ScoreBadge({
    super.key,
    required this.score,
    this.label,
    this.height = 28,
  });

  Color _bandColor(double s) {
    if (s >= 80) return C.success;
    if (s >= 65) return C.primary;
    if (s >= 45) return C.warning;
    return C.error;
  }

  @override
  Widget build(BuildContext context) {
    final s = score.clamp(0.0, 100.0).toDouble();
    final band = _bandColor(s);

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: C.glassWhite,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: band.withValues(alpha: 0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: band.withValues(alpha: 0.18),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: band, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label == null
                ? s.toStringAsFixed(0)
                : '${label!} ${s.toStringAsFixed(0)}',
            style: const TextStyle(
              color: C.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const StatusPill({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.40), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}