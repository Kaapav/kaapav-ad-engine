import 'package:flutter/material.dart';
import '../core/theme.dart';

class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const ShimmerBox({super.key, this.width, this.height = 16, this.radius = 8});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _a = Tween<double>(begin: -2, end: 2).animate(_c);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(_a.value - 1, 0),
            end: Alignment(_a.value + 1, 0),
            colors: [C.glassWhite, const Color(0x26FFFFFF), C.glassWhite],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: C.glassWhite, shape: BoxShape.circle, border: Border.all(color: C.glassBorder)),
              child: Icon(icon, color: C.textMuted, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: C.textPrimary, fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: const TextStyle(color: C.textMuted, fontSize: 13), textAlign: TextAlign.center),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(gradient: C.primaryGrad, borderRadius: BorderRadius.circular(12)),
                  child: Text(actionLabel!, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}