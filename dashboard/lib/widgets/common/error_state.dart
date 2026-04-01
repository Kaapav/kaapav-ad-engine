import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';
import 'glass_card.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorState({super.key, this.message = 'Something went wrong', this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: KaapavColors.error,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: KaapavColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KaapavColors.error.withOpacity(0.2)),
            ),
            child: const Icon(LucideIcons.alertTriangle, color: KaapavColors.error, size: 24),
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 14, color: KaapavColors.dark300), textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(LucideIcons.refreshCw, size: 16), label: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
