import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ui_provider.dart';

class _NavItem {
  final String path;
  final IconData icon;
  final String label;
  const _NavItem(this.path, this.icon, this.label);
}

final _navItems = [
  _NavItem('/', LucideIcons.layoutDashboard, 'Overview'),
  _NavItem('/campaigns', LucideIcons.megaphone, 'Campaigns'),
  _NavItem('/audiences', LucideIcons.users, 'Audiences'),
  _NavItem('/analytics', LucideIcons.barChart3, 'Analytics'),
  _NavItem('/customers', LucideIcons.userCircle, 'Customers'),
  _NavItem('/optimizer', LucideIcons.bot, 'Optimizer'),
  _NavItem('/catalog', LucideIcons.box, 'Catalog Feed'),
  _NavItem('/settings', LucideIcons.settings, 'Settings'),
];

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(sidebarExpandedProvider);
    final currentPath = GoRouterState.of(context).matchedLocation;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isExpanded ? 256 : 78,
      decoration: BoxDecoration(
        color: KaapavColors.dark900.withOpacity(0.8),
        border: Border(right: BorderSide(color: KaapavColors.dark700.withOpacity(0.5))),
      ),
      child: Column(children: [
        SizedBox(height: 64, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [KaapavColors.kaapav500, KaapavColors.kaapav700]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: KaapavColors.kaapav500.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 20)),
            if (isExpanded) ...[
              const SizedBox(width: 12),
              const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('KAAPAV', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.2)),
                Text('AD ENGINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: KaapavColors.dark400)),
              ]),
            ],
          ]),
        )),
        const Divider(height: 1),
        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          children: _navItems.map((item) {
            final isActive = item.path == '/' ? currentPath == '/' : currentPath.startsWith(item.path);
            return Padding(padding: const EdgeInsets.only(bottom: 4), child: GestureDetector(
              onTap: () => context.go(item.path),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isExpanded ? 12 : 0, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? KaapavColors.kaapav600.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isActive ? Border.all(color: KaapavColors.kaapav500.withOpacity(0.2)) : null,
                ),
                child: Row(
                  mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    if (isActive) Container(width: 3, height: 20, margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: KaapavColors.kaapav500, borderRadius: BorderRadius.circular(2))),
                    Icon(item.icon, size: 20, color: isActive ? KaapavColors.kaapav400 : KaapavColors.dark400),
                    if (isExpanded) ...[const SizedBox(width: 12),
                      Expanded(child: Text(item.label, style: TextStyle(fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? Colors.white : KaapavColors.dark400), overflow: TextOverflow.ellipsis))],
                  ],
                ),
              ),
            ));
          }).toList(),
        )),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          GestureDetector(
            onTap: () => ref.read(sidebarExpandedProvider.notifier).state = !isExpanded,
            child: Container(padding: EdgeInsets.symmetric(horizontal: isExpanded ? 12 : 0, vertical: 10),
              child: Row(mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                Icon(isExpanded ? LucideIcons.chevronsLeft : LucideIcons.chevronsRight, size: 20, color: KaapavColors.dark400),
                if (isExpanded) ...[const SizedBox(width: 12), const Text('Collapse', style: TextStyle(fontSize: 13, color: KaapavColors.dark400))],
              ]))),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () { ref.read(authProvider.notifier).logout(); context.go('/login'); },
            child: Container(padding: EdgeInsets.symmetric(horizontal: isExpanded ? 12 : 0, vertical: 10),
              child: Row(mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                const Icon(LucideIcons.logOut, size: 20, color: KaapavColors.dark400),
                if (isExpanded) ...[const SizedBox(width: 12), const Text('Logout', style: TextStyle(fontSize: 13, color: KaapavColors.dark400))],
              ]))),
        ])),
      ]),
    );
  }
}
