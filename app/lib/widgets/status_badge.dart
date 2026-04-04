import 'package:flutter/material.dart';
import '../core/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color get _color => switch (status.toUpperCase()) {
        'ACTIVE' => C.success,
        'PAUSED' || 'CAMPAIGN_PAUSED' => C.textMuted,
        'LEARNING' || 'IN_PROCESS' => C.learning,
        'ERROR' || 'DISAPPROVED' => C.error,
        _ => C.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(status, style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}