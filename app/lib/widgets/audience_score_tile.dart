import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/audience_score.dart';
import 'glass_card.dart';
import 'score_badge.dart';

class AudienceScoreTile extends StatelessWidget {
  final AudienceScore audience;
  final VoidCallback? onTap;

  const AudienceScoreTile({
    super.key,
    required this.audience,
    this.onTap,
  });

  Color get _statusColor {
    switch (audience.status) {
      case 'hot':      return C.success;
      case 'scalable': return C.primary;
      case 'watch':    return C.warning;
      case 'kill':     return C.error;
      default:         return C.textMuted;
    }
  }

  IconData get _statusIcon {
    switch (audience.status) {
      case 'hot':      return Icons.local_fire_department_rounded;
      case 'scalable': return Icons.trending_up_rounded;
      case 'watch':    return Icons.visibility_rounded;
      case 'kill':     return Icons.stop_circle_rounded;
      default:         return Icons.people_alt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;

    return GlassCard(
      radius:  18,
      padding: const EdgeInsets.all(14),
      onTap:   onTap,
      child: Row(
        children: [
          // Score badge
          ScoreBadge(
            score:     audience.intentScore,
            size:      52,
            showLabel: true,
          ),
          const SizedBox(width: 14),

          // Main info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + status chip
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        audience.audienceName,
                        style: const TextStyle(
                          color:      C.textPrimary,
                          fontSize:   13,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines:  1,
                        overflow:  TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical:   4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon, color: color, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            audience.status.toUpperCase(),
                            style: TextStyle(
                              color:      color,
                              fontSize:   9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Metrics row
                Row(
                  children: [
                    _metricChip(
                      'ROAS',
                      U.roas(audience.roas),
                      audience.roas >= 4
                          ? C.success
                          : audience.roas >= 2
                              ? C.primary
                              : C.error,
                    ),
                    const SizedBox(width: 8),
                    _metricChip(
                      'CPA',
                      U.money(audience.cpa),
                      audience.cpa <= 150
                          ? C.success
                          : audience.cpa <= 250
                              ? C.warning
                              : C.error,
                    ),
                    const SizedBox(width: 8),
                    _metricChip(
                      'CTR',
                      U.pct(audience.ctr),
                      audience.ctr >= 3 ? C.success : C.textMuted,
                    ),
                    const SizedBox(width: 8),
                    _metricChip(
                      'Freq',
                      audience.frequency.toStringAsFixed(1),
                      audience.frequency >= 3.5
                          ? C.warning
                          : C.textMuted,
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Spend + Revenue
                Row(
                  children: [
                    Text(
                      'Spend ${U.money(audience.spend)}',
                      style: const TextStyle(
                        color:    C.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '•',
                      style: TextStyle(color: C.textMuted, fontSize: 10),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Revenue ${U.money(audience.revenue)}',
                      style: const TextStyle(
                        color:    C.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),

                // Top reason
                if (audience.reasons.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    audience.reasons.first,
                    style: TextStyle(
                      color:    color.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        C.glassWhite,
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: C.glassBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color:      color,
              fontSize:   10,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color:    C.textMuted,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}