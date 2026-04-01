import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/common/animated_background.dart';
import 'sidebar.dart';
import 'app_header.dart';
import 'mobile_nav.dart';
import 'responsive_builder.dart';

class DashboardShell extends StatefulWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final _key = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(builder: (context, screen) {
      if (screen == ScreenType.mobile) {
        return Scaffold(key: _key, backgroundColor: KaapavColors.dark950,
          drawer: const Drawer(backgroundColor: KaapavColors.dark900, width: 280, child: Sidebar()),
          body: AnimatedBackground(child: Column(children: [
            Container(color: KaapavColors.dark950.withOpacity(0.5),
              child: SafeArea(bottom: false, child: AppHeader(onMenuTap: () => _key.currentState?.openDrawer()))),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: widget.child)),
          ])),
          bottomNavigationBar: const MobileNav());
      }
      if (screen == ScreenType.tablet) {
        return Scaffold(backgroundColor: KaapavColors.dark950,
          body: AnimatedBackground(child: Row(children: [
            const SizedBox(width: 78, child: Sidebar()),
            Expanded(child: Column(children: [
              SafeArea(bottom: false, child: AppHeader()),
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: widget.child)),
            ])),
          ])));
      }
      return Scaffold(backgroundColor: KaapavColors.dark950,
        body: AnimatedBackground(child: Row(children: [
          const Sidebar(),
          Expanded(child: Column(children: [
            const AppHeader(),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: widget.child)),
          ])),
        ])));
    });
  }
}
