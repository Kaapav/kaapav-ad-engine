import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';

class KaapavApp extends StatelessWidget {
  const KaapavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kaapav Ad Engine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}