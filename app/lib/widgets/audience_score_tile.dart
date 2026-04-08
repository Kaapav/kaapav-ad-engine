import 'package:flutter/material.dart';
import 'package:kaapav_ad_engine/core/theme.dart';
import 'package:kaapav_ad_engine/core/utils.dart';
import 'package:kaapav_ad_engine/models/audience_score.dart';
import 'package:kaapav_ad_engine/widgets/glass_card.dart';
import 'package:kaapav_ad_engine/widgets/score_badge.dart';

class AudienceScoreTile extends StatelessWidget {
  final AudienceScore a;
  final VoidCallback? onTap;

  const AudienceScoreTile({
    super.key,
    required this.a,
    this.onTap,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'hot':
        return C.success;
      case 'scalable':
        return C.primary;
      case 'watch':
        return C.warning;
      case 'kill':
        return C.error;
      default:
        return C.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(a.status);

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: C.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              StatusPill(text: a.status.toUpperCase(), color: sc),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ScoreBadge(score: a.intentScore, label: 'Intent'),
              _mini(
                'ROAS',
                U.roas(a.roas),
                a.roas >= 4 ? C.success : (a.roas >= 2 ? C.primary : C.error),
              ),
              _mini('Spend', U.money(a.spend), C.textSecondary),
              _mini('CPA', U.money(a.cpa), a.cpa <= 150 ? C.success : C.warning),
              _mini(
                'Freq',
                '${a.frequency.toStringAsFixed(2)}x',
                a.frequency >= 3.5 ? C.warning : C.textSecondary,
              ),
            ],
          ),
          if (a.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              a.reasons.first,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: C.textSecondary.withValues(alpha: 0.95),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: C.glassWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: C.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}