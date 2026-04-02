import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import 'glass_card.dart';

class LeadTile extends StatelessWidget {
  final String name;
  final String phone;
  final String campaign;
  final String stage;
  final DateTime date;
  final VoidCallback? onTap;

  const LeadTile({
    super.key,
    required this.name,
    required this.phone,
    required this.campaign,
    required this.stage,
    required this.date,
    this.onTap,
  });

  Color get _stageColor => switch (stage) {
        'New' => C.info,
        'Contacted' => C.warning,
        'Qualified' => C.purple,
        'Converted' => C.success,
        'Lost' => C.error,
        _ => C.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _stageColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: _stageColor, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: C.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('$phone • $campaign', style: const TextStyle(color: C.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _stageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(stage, style: TextStyle(color: _stageColor, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Text(U.ago(date), style: const TextStyle(color: C.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}