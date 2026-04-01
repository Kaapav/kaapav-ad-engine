import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';

class OptimizerAction {
  final String type;
  final String adName;
  final double roas;
  final String reason;
  final DateTime timestamp;
  const OptimizerAction({required this.type, required this.adName, required this.roas, required this.reason, required this.timestamp});
}

class OptimizerLogList extends StatelessWidget {
  final List<OptimizerAction> actions;
  const OptimizerLogList({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: KaapavColors.kaapav500.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(LucideIcons.bot, size: 16, color: KaapavColors.kaapav400)),
              const SizedBox(width: 10),
              const Text('Optimizer Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                child: Text(actions.length.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KaapavColors.dark300))),
            ]),
            const SizedBox(height: 16),
            ...actions.map((a) {
              final color = a.type == 'scaled' ? KaapavColors.success : a.type == 'paused' ? KaapavColors.warning : KaapavColors.error;
              final icon = a.type == 'scaled' ? LucideIcons.rocket : a.type == 'paused' ? LucideIcons.pauseCircle : LucideIcons.alertTriangle;
              final label = a.type.toUpperCase();
              final roasColor = Fmt.roasColor(a.roas);
              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withOpacity(0.04), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.08))),
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8)]),
                    child: Icon(icon, size: 16, color: color)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(a.adName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 4),
                    Text(a.reason + ' \u{2022} ' + Fmt.timeAgo(a.timestamp), style: const TextStyle(fontSize: 11, color: KaapavColors.dark400), overflow: TextOverflow.ellipsis),
                  ])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: roasColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: roasColor.withOpacity(0.2))),
                    child: Text(Fmt.roas(a.roas), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: roasColor))),
                ]));
            }),
          ]))));
  }
}
