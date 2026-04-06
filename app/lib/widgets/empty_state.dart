import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'buttons.dart';
import 'glass_card.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          radius: 18,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: C.glassWhite,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.glassBorder),
                ),
                child: Icon(
                  icon,
                  color: C.textMuted,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: C.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: C.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                OutlineBtn(
                  label: actionLabel!,
                  icon: Icons.add_rounded,
                  onTap: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}