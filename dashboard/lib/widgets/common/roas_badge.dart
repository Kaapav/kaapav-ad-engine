import 'package:flutter/material.dart';
import '../../utils/formatters.dart';

class RoasBadge extends StatelessWidget {
  final double roas;
  const RoasBadge({super.key, required this.roas});

  @override
  Widget build(BuildContext context) {
    final color = Fmt.roasColor(roas);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12)],
      ),
      child: Text(Fmt.roas(roas), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
