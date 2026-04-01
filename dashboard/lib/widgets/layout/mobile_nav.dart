import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';

class _MobileItem {
  final String path;
  final IconData icon;
  final String label;
  const _MobileItem(this.path, this.icon, this.label);
}

final _items = [
  _MobileItem('/', LucideIcons.layoutDashboard, 'Home'),
  _MobileItem('/campaigns', LucideIcons.megaphone, 'Campaigns'),
  _MobileItem('/analytics', LucideIcons.barChart3, 'Analytics'),
  _MobileItem('/optimizer', LucideIcons.bot, 'Optimizer'),
  _MobileItem('/settings', LucideIcons.settings, 'Settings'),
];

class MobileNav extends StatelessWidget {
  const MobileNav({super.key});

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).matchedLocation;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: KaapavColors.dark900.withOpacity(0.95),
        border: Border(top: BorderSide(color: KaapavColors.dark700.withOpacity(0.5))),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _items.map((item) {
            final isActive = item.path == '/'
                ? current == '/'
                : current.startsWith(item.path);
            return GestureDetector(
              onTap: () => context.go(item.path),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? KaapavColors.kaapav600.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, size: 22,
                        color: isActive ? KaapavColors.kaapav400 : KaapavColors.dark500),
                    ),
                    const SizedBox(height: 2),
                    Text(item.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? KaapavColors.kaapav400 : KaapavColors.dark500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}