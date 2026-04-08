import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../services/biometric_service.dart';
import '../services/meta_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introC;
  late final AnimationController _pulseC;

  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _logoFloat;
  late final Animation<double> _glowPulse;

  bool _authFailed = false;
  bool _checkingBiometric = false;
  bool _isAuthenticating = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _introC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _fade = CurvedAnimation(
      parent: _introC,
      curve: Curves.easeOutCubic,
    );

    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _introC,
        curve: Curves.easeOutBack,
      ),
    );

    _logoFloat = Tween<double>(begin: 8, end: 0).animate(
      CurvedAnimation(
        parent: _introC,
        curve: Curves.easeOutCubic,
      ),
    );

    _glowPulse = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseC,
        curve: Curves.easeInOut,
      ),
    );

    _introC.forward();
    _pulseC.repeat(reverse: true);

    // ✅ start after first frame (fixes "biometric not showing" on some devices)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startFlow();
    });
  }

  Future<String> _decideNextRoute() async {
    final auth = MetaAuth();

    final onboarded = await auth.isOnboarded();
    if (!onboarded) return '/onboarding';

    final hasApiKey = await auth.hasApiKey();
    final session = await auth.getSessionToken();
    final hasSession = session != null && session.trim().isNotEmpty;

    if (hasApiKey || hasSession) return '/dashboard';
    return '/connect';
  }

  Future<void> _startFlow() async {
    if (_isAuthenticating || _navigated) return;
    _isAuthenticating = true;

    if (mounted) {
      setState(() {
        _authFailed = false;
        _checkingBiometric = false;
      });
    }

    // let intro animation play a bit
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _navigated) {
      _isAuthenticating = false;
      return;
    }

    if (mounted) {
      setState(() => _checkingBiometric = true);
    }

    try {
      // ✅ timeouts prevent permanent freeze
      final biometricAvailable = await BiometricService.isAvailable()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);

      if (!mounted || _navigated) {
        _isAuthenticating = false;
        return;
      }

      if (biometricAvailable) {
        final authenticated = await BiometricService.authenticate()
            .timeout(const Duration(seconds: 12), onTimeout: () => false);

        if (!mounted || _navigated) {
          _isAuthenticating = false;
          return;
        }

        if (!authenticated) {
          setState(() {
            _checkingBiometric = false;
            _authFailed = true;
          });
          _isAuthenticating = false;
          return;
        }
      }

      final route = await _decideNextRoute();
      _go(route);
    } catch (_) {
      if (!mounted || _navigated) {
        _isAuthenticating = false;
        return;
      }

      setState(() {
        _checkingBiometric = false;
        _authFailed = true;
      });
    } finally {
      _isAuthenticating = false;
    }
  }

  void _go(String route) {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go(route);
  }

  Future<void> _retry() async {
    if (_isAuthenticating || _navigated) return;
    await _startFlow();
  }

  Future<void> _continueAnyway() async {
    if (_navigated) return;
    final route = await _decideNextRoute();
    _go(route);
  }

  @override
  void dispose() {
    _introC.dispose();
    _pulseC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _AnimatedBackground(glowPulse: _glowPulse),
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_introC, _pulseC]),
                builder: (_, __) {
                  return Opacity(
                    opacity: _fade.value,
                    child: Transform.translate(
                      offset: Offset(0, _logoFloat.value),
                      child: Transform.scale(
                        scale: _scale.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LogoHero(glowPulse: _glowPulse.value),
                            const SizedBox(height: 28),
                            const Text(
                              'Kaapav',
                              style: TextStyle(
                                color: C.textPrimary,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'AD ENGINE',
                              style: TextStyle(
                                color: C.primary.withValues(alpha: 0.92),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 3.2,
                              ),
                            ),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              child: _buildStatusSection(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    if (_authFailed) {
      return Column(
        key: const ValueKey('failed'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Authentication failed',
            style: TextStyle(
              color: C.error,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _retry,
                style: TextButton.styleFrom(foregroundColor: C.primary),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _continueAnyway,
                style: TextButton.styleFrom(foregroundColor: C.textSecondary),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (_checkingBiometric) {
      return Column(
        key: const ValueKey('checking'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: C.primary,
              backgroundColor: C.glassBorder,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Authenticating...',
            style: TextStyle(
              color: C.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return const Text(
      'Secure startup',
      key: ValueKey('idle'),
      style: TextStyle(
        color: C.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _LogoHero extends StatelessWidget {
  const _LogoHero({required this.glowPulse});
  final double glowPulse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      height: 156,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: glowPulse,
            child: Container(
              width: 138,
              height: 138,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    C.primary.withValues(alpha: 0.28),
                    C.blue.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: C.primary.withValues(alpha: 0.24),
                    blurRadius: 42,
                    spreadRadius: 8,
                  ),
                  BoxShadow(
                    color: C.blue.withValues(alpha: 0.10),
                    blurRadius: 56,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: C.glassTurqBorder.withValues(alpha: 0.7),
                width: 1.2,
              ),
              gradient: RadialGradient(
                colors: [
                  C.glassWhite.withValues(alpha: 0.12),
                  C.glassTurq.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.58, 1.0],
              ),
            ),
          ),
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  C.glassTurq.withValues(alpha: 0.08),
                  C.bgCard.withValues(alpha: 0.22),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: C.primary.withValues(alpha: 0.18),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                'assets/branding/splash_logo.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground({required this.glowPulse});
  final Animation<double> glowPulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowPulse,
      builder: (_, __) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                C.bgDeep,
                C.bg,
                C.bgCard.withValues(alpha: 0.95),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: const Alignment(0, -0.18),
                child: Transform.scale(
                  scale: glowPulse.value,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          C.primary.withValues(alpha: 0.16),
                          C.blue.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.52, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0.7, -0.75),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        C.blue.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(-0.75, 0.86),
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        C.primary.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}