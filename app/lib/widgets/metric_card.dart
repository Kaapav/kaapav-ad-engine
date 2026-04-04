import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'glass_card.dart';
import 'common.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? change;
  final bool isUp;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.isUp = true,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (change != null) ChangePill(change: change!, isUp: isUp),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: C.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: C.textMuted, fontSize: 10, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}