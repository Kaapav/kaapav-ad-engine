// REPLACE entire file:
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/router.dart';

class KaapavAdEngine extends StatelessWidget {
  const KaapavAdEngine({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kaapav Ad Engine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
    );
  }
}