import 'package:flutter/material.dart';
import 'core/router.dart';
import 'core/theme.dart';

class KaapavAdEngine extends StatelessWidget {
  const KaapavAdEngine({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kaapav Ad Engine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark, // force dark for glass UI consistency
      routerConfig: AppRouter.router,
    );
  }
}