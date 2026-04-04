import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

class PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;
  final bool expanded;

  const PrimaryBtn({super.key, required this.label, this.onTap, this.icon, this.loading = false, this.expanded = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : () { HapticFeedback.mediumImpact(); onTap?.call(); },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null || loading ? 0.5 : 1.0,
        child: Container(
          width: expanded ? double.infinity : null,
          height: 50,
          padding: expanded ? null : const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: C.primaryGrad,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
              : Row(
                  mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, color: Colors.black, size: 18), const SizedBox(width: 8)],
                    Text(label, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
        ),
      ),
    );
  }
}

class OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  const OutlineBtn({super.key, required this.label, this.onTap, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.primary;
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap?.call(); },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: c, size: 16), const SizedBox(width: 6)],
            Text(label, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool badge;
  final String? badgeCount;

  const GlassIconBtn({super.key, required this.icon, this.onTap, this.badge = false, this.badgeCount});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: Glass.card(radius: 12),
            child: Icon(icon, color: C.textPrimary, size: 20),
          ),
          if (badge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: badgeCount != null ? null : 8,
                height: badgeCount != null ? null : 8,
                padding: badgeCount != null ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1) : null,
                decoration: BoxDecoration(
                  gradient: C.primaryGrad,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: badgeCount != null
                    ? Text(badgeCount!, style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w700))
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}