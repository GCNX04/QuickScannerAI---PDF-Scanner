import 'package:flutter/material.dart';

/// Fade + slight vertical slide for premium route transitions.
class AppPageRoutes {
  AppPageRoutes._();

  static Route<T> fadeSlide<T extends Object?>({
    required Widget child,
    Duration duration = const Duration(milliseconds: 420),
    Duration reverseDuration = const Duration(milliseconds: 320),
  }) {
    return PageRouteBuilder<T>(
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
          reverseCurve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.024),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
