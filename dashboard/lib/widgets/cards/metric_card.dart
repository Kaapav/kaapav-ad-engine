import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final double? changePercent;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const MetricCard({super.key, required this.title, required this.value, this.subtitle, this.changePercent, required this.icon, this.accentColor = KaapavColors.kaapav500, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pos = (changePercent ?? 0) >= 0;
    return GestureDetector(onTap: onTap, child: ClipRRect(borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [BoxShadow(color: accentColor.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8)),
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withOpacity(0.2)),
                  boxShadow: [BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 8)]),
                child: Icon(icon, size: 18, color: accentColor)),
              const Spacer(),
              if (changePercent != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (pos ? KaapavColors.success : KaapavColors.error).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (pos ? KaapavColors.success : KaapavColors.error).withOpacity(0.2))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(pos ? LucideIcons.trendingUp : LucideIcons.trendingDown, size: 12, color: pos ? KaapavColors.success : KaapavColors.error),
                  const SizedBox(width: 3),
                  Text(changePercent!.abs().toStringAsFixed(1) + '%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pos ? KaapavColors.success : KaapavColors.error)),
                ])),
            ]),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: KaapavColors.dark400)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
            if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: const TextStyle(fontSize: 11, color: KaapavColors.dark500))],
            const SizedBox(height: 12),
            Container(height: 3, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(colors: [accentColor.withOpacity(0.6), accentColor.withOpacity(0.0)]))),
          ])))));
  }
}
