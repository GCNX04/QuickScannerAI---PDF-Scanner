import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/subscription_service.dart';
import 'paywall_navigation.dart';

/// If the user already has Pro, returns `true` immediately.
/// Otherwise opens [PaywallScreen] and returns `true` only if they subscribed before it closed.
Future<bool> requirePro(BuildContext context) async {
  final sub = context.read<SubscriptionService>();
  await sub.loadSubscriptionStatus();
  if (!context.mounted) return false;
  if (sub.isPro) return true;

  final subscribed = await openPaywall(context);
  if (!context.mounted) return false;

  await sub.loadSubscriptionStatus();
  if (!context.mounted) return false;

  final ok = subscribed == true && sub.isPro;
  return ok || sub.isPro;
}
