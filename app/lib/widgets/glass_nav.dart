import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

class GlassNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassNav({super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    (Icons.grid_view_rounded, 'Dashboard'),
    (Icons.campaign_rounded, 'Campaigns'),
    (Icons.people_alt_rounded, 'CRM'),
    (Icons.auto_awesome_rounded, 'AutoPilot'),
    (Icons.menu_rounded, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: Glass.blur,
          child: Container(
            height: 68,
            decoration: Glass.card(radius: 28, turquoise: true, glow: true),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_items.length, (i) {
                final active = i == currentIndex;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap(i);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: active
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: C.primary.withValues(alpha: 0.15),
                            border: Border.all(color: C.primary.withValues(alpha: 0.4)),
                            boxShadow: [
                              BoxShadow(
                                color: C.primary.withValues(alpha: 0.2),
                                blurRadius: 10,
                              ),
                            ],
                          )
                        : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _items[i].$1,
                          color: active ? C.primary : C.textMuted,
                          size: active ? 24 : 22,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _items[i].$2,
                          style: TextStyle(
                            fontSize: active ? 10 : 9,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                            color: active ? C.primary : C.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}