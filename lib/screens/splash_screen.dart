import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/meta_auth.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _scale = Tween(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _c.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final auth = MetaAuth();
    final onboarded = await auth.isOnboarded();

    final destination = onboarded ? const MainShell() : const OnboardingScreen();

    if (mounted) {
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ));
    }
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      gradient: C.primaryGrad,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 4)],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.black, size: 40),
                  ),
                  const SizedBox(height: 24),
                  const Text('Kaapav', style: TextStyle(color: C.textPrimary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  const Text('Ad Engine', style: TextStyle(color: C.primary, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}