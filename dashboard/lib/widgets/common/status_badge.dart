import 'package:flutter/material.dart';

enum BadgeType { success, warning, error, info, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeType type;

  const StatusBadge({super.key, required this.label, this.type = BadgeType.neutral});

  Color get _color {
    switch (type) {
      case BadgeType.success: return const Color(0xFF34D399);
      case BadgeType.warning: return const Color(0xFFFBBF24);
      case BadgeType.error:   return const Color(0xFFF87171);
      case BadgeType.info:    return const Color(0xFF60A5FA);
      case BadgeType.neutral: return const Color(0xFF7B7D85);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: _color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _color.withOpacity(0.5), blurRadius: 4)])),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color)),
        ],
      ),
    );
  }
}
