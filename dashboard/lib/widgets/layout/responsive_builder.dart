import 'package:flutter/material.dart';

enum ScreenType { mobile, tablet, desktop }

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenType screenType) builder;
  const ResponsiveBuilder({super.key, required this.builder});

  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1100) return ScreenType.desktop;
    if (width >= 650) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  static bool isMobile(BuildContext context) => getScreenType(context) == ScreenType.mobile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) => builder(context, getScreenType(context)));
  }
}
