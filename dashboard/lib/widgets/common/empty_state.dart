import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'glass_card.dart';

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  const EmptyState({super.key, this.emoji = '📭', required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 14, color: KaapavColors.dark400), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
