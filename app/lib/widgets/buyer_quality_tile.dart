import 'package:flutter/material.dart';
import 'package:kaapav_ad_engine/core/theme.dart';
import 'package:kaapav_ad_engine/core/utils.dart';
import 'package:kaapav_ad_engine/models/buyer_quality.dart';
import 'package:kaapav_ad_engine/widgets/glass_card.dart';
import 'package:kaapav_ad_engine/widgets/score_badge.dart';

class BuyerQualityTile extends StatelessWidget {
  final BuyerQuality b;
  final VoidCallback? onTap;

  const BuyerQualityTile({
    super.key,
    required this.b,
    this.onTap,
  });

  Color _tierColor(String t) {
    switch (t) {
      case 'platinum':
        return C.primaryLight;
      case 'gold':
        return C.gold;
      case 'silver':
        return C.textSecondary;
      case 'risk':
        return C.error;
      default:
        return C.textMuted;
    }
  }

  double _prepaidPct() {
    // Worker could store 0-1 or 0-100. Normalize to 0-100.
    final v = b.prepaidRatio;
    if (v <= 1.0) return (v * 100).clamp(0, 100);
    return v.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final tc = _tierColor(b.buyerTier);
    final prepaidPct = _prepaidPct();

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
                  b.displayName,
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tc.withValues(alpha: 0.40)),
                ),
                child: Text(
                  b.buyerTier.toUpperCase(),
                  style: TextStyle(
                    color: tc,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ScoreBadge(score: b.buyerQualityScore, label: 'Quality'),
              _mini('Orders', '${b.totalOrders}', C.textSecondary),
              _mini('Revenue', U.money(b.totalRevenue), C.textSecondary),
              _mini('AOV', U.money(b.avgOrderValue), C.textSecondary),
              _mini(
                'Prepaid',
                U.pct(prepaidPct),
                prepaidPct >= 50 ? C.success : C.warning,
              ),
              _mini(
                'Refunds',
                '${b.refundCount}',
                b.refundCount > 0 ? C.warning : C.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (b.lookalikeSeedEligible)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: C.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: C.success.withValues(alpha: 0.40)),
                  ),
                  child: const Text(
                    'SEED ELIGIBLE',
                    style: TextStyle(
                      color: C.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  b.productAffinity == null || b.productAffinity!.trim().isEmpty
                      ? 'Product affinity: —'
                      : 'Product affinity: ${b.productAffinity}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: C.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
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