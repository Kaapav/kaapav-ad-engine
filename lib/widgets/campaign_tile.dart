import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import 'glass_card.dart';
import 'status_badge.dart';

class CampaignTile extends StatelessWidget {
  final String name;
  final String status;
  final String platform;
  final double spend;
  final double roas;
  final double cpa;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  const CampaignTile({
    super.key,
    required this.name,
    required this.status,
    required this.platform,
    required this.spend,
    required this.roas,
    required this.cpa,
    this.onTap,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isFb = platform.toLowerCase() == 'facebook';

    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          // PLATFORM ICON
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isFb
                    ? [C.facebook, const Color(0xFF0A5BC4)]
                    : [C.instagram, const Color(0xFF833AB4)],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isFb ? Icons.facebook_rounded : Icons.camera_alt_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // INFO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: C.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    StatusBadge(status: status),
                    const SizedBox(width: 6),
                    Text(U.money(spend), style: const TextStyle(color: C.textMuted, fontSize: 11)),
                    const SizedBox(width: 6),
                    Text('CPA ${U.money(cpa)}', style: const TextStyle(color: C.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          // ROAS BADGE
          if (roas > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: roas >= 4 ? C.successGrad : roas >= 2 ? C.primaryGrad : C.dangerGrad,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${roas.toStringAsFixed(1)}x',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}