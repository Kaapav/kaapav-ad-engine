import 'package:flutter/material.dart';
import '../../config/theme.dart';

class LoadingShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  const LoadingShimmer({super.key, this.width = double.infinity, this.height = 120, this.borderRadius = 20});

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width, height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (2.0 * _controller.value), 0),
              end: Alignment(-0.5 + (2.0 * _controller.value), 0),
              colors: [
                KaapavColors.dark800.withOpacity(0.3),
                KaapavColors.dark700.withOpacity(0.4),
                KaapavColors.dark800.withOpacity(0.3),
              ],
            ),
            border: Border.all(color: KaapavColors.glassBorder),
          ),
        );
      },
    );
  }
}
