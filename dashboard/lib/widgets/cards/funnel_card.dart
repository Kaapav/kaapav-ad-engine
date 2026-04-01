import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';

class FunnelStep {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const FunnelStep({required this.label, required this.value, required this.color, required this.icon});
}

class FunnelCard extends StatelessWidget {
  final List<FunnelStep> steps;
  const FunnelCard({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final max = steps.isNotEmpty ? steps.first.value : 1;
    return ClipRRect(borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: KaapavColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(LucideIcons.filter, size: 16, color: KaapavColors.info)),
              const SizedBox(width: 10),
              const Text('Conversion Funnel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
            const SizedBox(height: 20),
            ...steps.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              final fill = max > 0 ? (s.value / max).clamp(0.0, 1.0) : 0.0;
              String? rate;
              if (i > 0 && steps[i - 1].value > 0) rate = (s.value / steps[i - 1].value * 100).toStringAsFixed(1) + '%';
              return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(s.icon, size: 14, color: s.color), const SizedBox(width: 8),
                  Text(s.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: KaapavColors.dark300)),
                  const Spacer(),
                  Text(Fmt.numberShort(s.value), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  if (rate != null) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: s.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(rate, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: s.color)))],
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: Stack(children: [
                  Container(height: 8, decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(4))),
                  FractionallySizedBox(widthFactor: fill, child: Container(height: 8,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(colors: [s.color, s.color.withOpacity(0.6)]),
                      boxShadow: [BoxShadow(color: s.color.withOpacity(0.3), blurRadius: 6)]))),
                ])),
              ]));
            }),
          ]))));
  }
}
