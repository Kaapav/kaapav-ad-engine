import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/buyer_quality.dart';
import 'glass_card.dart';
import 'score_badge.dart';

class BuyerQualityTile extends StatelessWidget {
  final BuyerQuality buyer;
  final VoidCallback? onTap;

  const BuyerQualityTile({
    super.key,
    required this.buyer,
    this.onTap,
  });

  Color get _tierColor {
    switch (buyer.buyerTier) {
      case 'platinum': return C.primary;
      case 'gold':     return C.gold;
      case 'silver':   return C.textSecondary;
      case 'risk':     return C.error;
      default:         return C.textMuted;
    }
  }

  IconData get _tierIcon {
    switch (buyer.buyerTier) {
      case 'platinum': return Icons.workspace_premium_rounded;
      case 'gold':     return Icons.star_rounded;
      case 'silver':   return Icons.star_half_rounded;
      case 'risk':     return Icons.warning_amber_rounded;
      default:         return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor;

    return GlassCard(
      radius:  18,
      padding: const EdgeInsets.all(14),
      onTap:   onTap,
      child: Row(
        children: [
          // Score badge
          ScoreBadge(
            score:     buyer.buyerQualityScore,
            size:      52,
            showLabel: true,
          ),
          const SizedBox(width: 14),

          // Main info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + tier
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        buyer.customerName,
                        style: const TextStyle(
                          color:      C.textPrimary,
                          fontSize:   13,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical:   4,
                      ),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: tierColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_tierIcon, color: tierColor, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            buyer.buyerTier.toUpperCase(),
                            style: TextStyle(
                              color:      tierColor,
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
                    _chip(
                      'Orders',
                      '${buyer.totalOrders}',
                      buyer.totalOrders >= 2
                          ? C.success
                          : C.textMuted,
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      'AOV',
                      U.money(buyer.avgOrderValue),
                      buyer.avgOrderValue >= 2000
                          ? C.gold
                          : C.textMuted,
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      'LTV',
                      U.money(buyer.totalRevenue),
                      C.primary,
                    ),
                    const SizedBox(width: 8),
                    if (buyer.refundCount > 0)
                      _chip(
                        'Refunds',
                        '${buyer.refundCount}',
                        C.error,
                      ),
                  ],
                ),

                const SizedBox(height: 6),

                // Bottom row: affinity + seed badge
                Row(
                  children: [
                    Text(
                      buyer.productAffinity.toUpperCase(),
                      style: const TextStyle(
                        color:      C.textMuted,
                        fontSize:   10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (buyer.isSeedEligible)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical:   3,
                        ),
                        decoration: BoxDecoration(
                          gradient:     C.primaryGrad,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.grain_rounded,
                              color: Colors.black,
                              size:  10,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'SEED',
                              style: TextStyle(
                                color:      Colors.black,
                                fontSize:   9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
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

  Widget _chip(String label, String value, Color color) {
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
            style: const TextStyle(color: C.textMuted, fontSize: 8),
          ),
        ],
      ),
    );
  }
}