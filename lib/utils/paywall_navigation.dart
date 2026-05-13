import 'package:flutter/material.dart';

import '../screens/paywall_screen.dart';

/// Pushes the paywall; returns `true` if user became entitled before pop.
Future<bool?> openPaywall(BuildContext context) {
  return Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      pageBuilder: (context, animation, secondaryAnimation) => const PaywallScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
    ),
  );
}
