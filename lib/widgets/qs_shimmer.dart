import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight shimmer bar for skeleton placeholders.
class QsShimmer extends StatefulWidget {
  const QsShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<QsShimmer> createState() => _QsShimmerState();
}

class _QsShimmerState extends State<QsShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? AppColors.graphiteElevated;
    final hi = widget.highlightColor ?? AppColors.stroke.withValues(alpha: 0.9);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [base, hi, base],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-1.1 + 2.2 * _c.value, 0),
              end: Alignment(-0.1 + 2.2 * _c.value, 0),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
