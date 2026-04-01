import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/theme.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with TickerProviderStateMixin {
  late AnimationController _c1;
  late AnimationController _c2;
  late AnimationController _c3;

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _c2 = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat(reverse: true);
    _c3 = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      decoration: const BoxDecoration(gradient: KaapavColors.meshGradient1),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _c1,
            builder: (context, child) => Positioned(
              top: -80 + (60 * _c1.value),
              right: -60 + (40 * sin(_c1.value * pi)),
              child: _Orb(size: 300, color: KaapavColors.kaapav600, opacity: 0.12),
            ),
          ),
          AnimatedBuilder(
            animation: _c2,
            builder: (context, child) => Positioned(
              bottom: -100 + (80 * _c2.value),
              left: -80 + (50 * sin(_c2.value * pi)),
              child: _Orb(size: 350, color: const Color(0xFF8B5CF6), opacity: 0.08),
            ),
          ),
          AnimatedBuilder(
            animation: _c3,
            builder: (context, child) => Positioned(
              top: h * 0.4,
              right: -40 + (60 * _c3.value),
              child: _Orb(size: 250, color: const Color(0xFF06B6D4), opacity: 0.06),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Orb({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withOpacity(opacity), color.withOpacity(0.0)]),
      ),
    );
  }
}
