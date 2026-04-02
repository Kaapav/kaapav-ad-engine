import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'glass_card.dart';

class RuleCard extends StatelessWidget {
  final String name;
  final String condition;
  final String action;
  final bool enabled;
  final int triggeredCount;
  final String? lastTriggered;
  final ValueChanged<bool>? onToggle;

  const RuleCard({
    super.key,
    required this.name,
    required this.condition,
    required this.action,
    required this.enabled,
    this.triggeredCount = 0,
    this.lastTriggered,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 18,
      turquoise: enabled,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (enabled ? C.primary : C.textMuted).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bolt_rounded, color: enabled ? C.primary : C.textMuted, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name, style: const TextStyle(color: C.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeTrackColor: C.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row(Icons.visibility_rounded, 'IF', condition),
          const SizedBox(height: 6),
          _row(Icons.play_arrow_rounded, 'THEN', action),
          if (triggeredCount > 0 || lastTriggered != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (triggeredCount > 0)
                  Text('Triggered $triggeredCount times', style: const TextStyle(color: C.textMuted, fontSize: 10)),
                const Spacer(),
                if (lastTriggered != null)
                  Text('Last: $lastTriggered', style: const TextStyle(color: C.textMuted, fontSize: 10)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String text) {
    return Row(
      children: [
        Icon(icon, color: C.primary.withValues(alpha: 0.6), size: 14),
        const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(color: C.primary.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600)),
        Expanded(child: Text(text, style: const TextStyle(color: C.textSecondary, fontSize: 11))),
      ],
    );
  }
}