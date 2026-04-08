import 'package:flutter/material.dart';
import 'package:kaapav_ad_engine/core/theme.dart';
import 'package:kaapav_ad_engine/core/utils.dart';
import 'package:kaapav_ad_engine/models/creative_match.dart';
import 'package:kaapav_ad_engine/widgets/glass_card.dart';
import 'package:kaapav_ad_engine/widgets/score_badge.dart';

class CreativeMatchTile extends StatelessWidget {
  final CreativeMatch m;
  final VoidCallback? onTap;

  const CreativeMatchTile({
    super.key,
    required this.m,
    this.onTap,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'winner':
        return C.success;
      case 'test':
        return C.primary;
      case 'fatiguing':
        return C.warning;
      case 'loser':
        return C.error;
      default:
        return C.textMuted;
    }
  }

  Color _fatigueColor(double f) {
    if (f >= 75) return C.error;
    if (f >= 50) return C.warning;
    if (f >= 25) return C.primary;
    return C.success;
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(m.status);

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
                  m.displayName,
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
              StatusPill(text: m.status.toUpperCase(), color: sc),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (m.productTag?.isNotEmpty ?? false) m.productTag!,
              if (m.angle?.isNotEmpty ?? false) m.angle!,
              if (m.hookType?.isNotEmpty ?? false) m.hookType!,
              if (m.creativeType?.isNotEmpty ?? false) m.creativeType!,
            ].join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: C.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ScoreBadge(score: m.matchScore, label: 'Match'),
              _mini(
                'Fatigue',
                m.fatigueScore.toStringAsFixed(0),
                _fatigueColor(m.fatigueScore),
              ),
              _mini(
                'ROAS',
                U.roas(m.roas),
                m.roas >= 4 ? C.success : (m.roas >= 2 ? C.primary : C.error),
              ),
              _mini('CTR', U.pct(m.ctr), m.ctr >= 2 ? C.success : C.warning),
              _mini('Spend', U.money(m.spend), C.textSecondary),
              _mini('Conv', '${m.conversions}', C.textSecondary),
            ],
          ),
          if (m.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              m.reasons.first,
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