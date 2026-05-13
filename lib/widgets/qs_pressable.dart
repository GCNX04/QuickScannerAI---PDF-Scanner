import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Subtle scale feedback on press (tactile + visual).
class QsPressable extends StatefulWidget {
  const QsPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.haptic = true,
    this.scale = 0.96,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool haptic;
  final double scale;

  @override
  State<QsPressable> createState() => _QsPressableState();
}

class _QsPressableState extends State<QsPressable> with SingleTickerProviderStateMixin {
  late final AnimationController _p = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 160),
  );

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  void _down() {
    if (widget.onPressed == null) return;
    if (widget.haptic) {
      HapticFeedback.lightImpact();
    }
    _p.forward();
  }

  void _up() {
    _p.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _down() : null,
      onTapUp: enabled ? (_) => _up() : null,
      onTapCancel: enabled ? _up : null,
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: widget.scale).animate(
          CurvedAnimation(parent: _p, curve: Curves.easeOutCubic, reverseCurve: Curves.easeOutCubic),
        ),
        child: widget.child,
      ),
    );
  }
}
