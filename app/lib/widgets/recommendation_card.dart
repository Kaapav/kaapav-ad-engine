import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/optimization_recommendation.dart';
import 'glass_card.dart';
import 'buttons.dart';

class RecommendationCard extends StatelessWidget {
  final OptimizationRecommendation rec;
  final VoidCallback? onApply;
  final VoidCallback? onDismiss;

  const RecommendationCard({
    super.key,
    required this.rec,
    this.onApply,
    this.onDismiss,
  });

  Color get _priorityColor {
    switch (rec.priority) {
      case 'critical': return C.error;
      case 'high':     return C.warning;
      case 'medium':   return C.info;
      default:         return C.textMuted;
    }
  }

  Color get _actionColor {
    switch (rec.actionType) {
      case 'scale_budget':    return C.success;
      case 'pause':           return C.error;
      case 'reduce_budget':   return C.warning;
      case 'rotate_creative': return C.purple;
      case 'retarget':        return C.blue;
      case 'duplicate':       return C.primary;
      default:                return C.textMuted;
    }
  }

  IconData get _actionIcon {
    switch (rec.actionType) {
      case 'scale_budget':    return Icons.trending_up_rounded;
      case 'pause':           return Icons.pause_circle_rounded;
      case 'reduce_budget':   return Icons.trending_down_rounded;
      case 'rotate_creative': return Icons.refresh_rounded;
      case 'retarget':        return Icons.ads_click_rounded;
      case 'duplicate':       return Icons.copy_all_rounded;
      default:                return Icons.auto_awesome_rounded;
    }
  }

  String get _actionLabel {
    switch (rec.actionType) {
      case 'scale_budget':    return 'Scale Budget';
      case 'pause':           return 'Pause';
      case 'reduce_budget':   return 'Reduce Budget';
      case 'rotate_creative': return 'Rotate Creative';
      case 'retarget':        return 'Retarget';
      case 'duplicate':       return 'Duplicate';
      default:                return rec.actionType
              .replaceAll('_', ' ')
              .toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color     = _priorityColor;
    final actColor  = _actionColor;
    final score     = rec.score ?? 0;

    return GlassCard(
      radius:  20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Priority banner ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: color.withValues(alpha: 0.20),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: color.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    rec.priority.toUpperCase(),
                    style: TextStyle(
                      color:      color,
                      fontSize:   9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: actColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: actColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _actionIcon,
                        color: actColor,
                        size:  12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _actionLabel,
                        style: TextStyle(
                          color:      actColor,
                          fontSize:   9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Score pill
                if (score > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: C.glassWhite,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Score ${score.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color:      C.textSecondary,
                        fontSize:   9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  U.ago(rec.createdAt),
                  style: const TextStyle(
                    color:    C.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // ── Content ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width:  42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: actColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: actColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        _actionIcon,
                        color: actColor,
                        size:  20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec.title,
                            style: const TextStyle(
                              color:      C.textPrimary,
                              fontSize:   13,
                              fontWeight: FontWeight.w900,
                              height:     1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rec.description,
                            style: const TextStyle(
                              color:    C.textSecondary,
                              fontSize: 11,
                              height:   1.5,
                            ),
                            maxLines:  4,
                            overflow:  TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Reasons chips ─────────────────────────────
                if (rec.payload?.containsKey('reasons') == true &&
    rec.payload?['reasons'] is List) ...[
  const SizedBox(height: 12),
  Wrap(
    spacing:    6,
    runSpacing: 6,
    children: (rec.payload!['reasons'] as List)
        .take(3)
        .map(
          (r) => Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical:   4,
            ),
            decoration: BoxDecoration(
              color:        C.glassWhite,
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: C.glassBorder),
            ),
            child: Text(
              r.toString(),
              style: const TextStyle(
                color:    C.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
        )
        .toList(),
  ),
],

                // ── Actions ───────────────────────────────────
                if (rec.isOpen &&
                    (onApply != null || onDismiss != null)) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (onApply != null)
                        Expanded(
                          child: PrimaryBtn(
                            label:   'Apply',
                            icon:    Icons.check_rounded,
                            onTap:   onApply,
                            loading: false,
                          ),
                        ),
                      if (onApply != null && onDismiss != null)
                        const SizedBox(width: 10),
                      if (onDismiss != null)
                        Expanded(
                          child: OutlineBtn(
                            label:  'Dismiss',
                            icon:   Icons.close_rounded,
                            color:  C.textMuted,
                            onTap:  onDismiss,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}