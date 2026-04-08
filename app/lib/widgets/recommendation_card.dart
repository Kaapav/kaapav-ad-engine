import 'package:flutter/material.dart';
import 'package:kaapav_ad_engine/core/theme.dart';
import 'package:kaapav_ad_engine/models/optimization_recommendation.dart';
import 'package:kaapav_ad_engine/widgets/buttons.dart';
import 'package:kaapav_ad_engine/widgets/glass_card.dart';
import 'package:kaapav_ad_engine/widgets/score_badge.dart';

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

  Color _priorityColor(String p) {
    switch (p) {
      case 'critical':
        return C.error;
      case 'high':
        return C.warning;
      case 'medium':
        return C.primary;
      case 'low':
        return C.textMuted;
      default:
        return C.primary;
    }
  }

  String _priorityLabel(String p) {
    switch (p) {
      case 'critical':
        return 'CRITICAL';
      case 'high':
        return 'HIGH';
      case 'medium':
        return 'MEDIUM';
      case 'low':
        return 'LOW';
      default:
        return p.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pc = _priorityColor(rec.priority);

    return GlassCard(
      turquoise: rec.isCritical,
      glow: rec.isCritical,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  rec.title,
                  style: const TextStyle(
                    color: C.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              StatusPill(text: _priorityLabel(rec.priority), color: pc),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rec.description,
            style: const TextStyle(
              color: C.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (rec.score != null) ScoreBadge(score: rec.score!, label: 'Score'),
              const Spacer(),
              StatusPill(text: rec.actionType.toUpperCase(), color: C.blue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrimaryBtn(
                  label: rec.isOpen ? 'Apply' : 'Applied',
                  onTap: rec.isOpen ? onApply : null,
                  icon: Icons.auto_awesome,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlineBtn(
                  label: 'Dismiss',
                  onTap: rec.isOpen ? onDismiss : null,
                  icon: Icons.close_rounded,
                  color: C.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}