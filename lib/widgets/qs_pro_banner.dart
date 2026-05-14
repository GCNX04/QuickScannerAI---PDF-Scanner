import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

class QsProBanner extends StatelessWidget {
  const QsProBanner({super.key, required this.onUnlockTap});

  final VoidCallback onUnlockTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionService>(
      builder: (context, sub, _) {
        final active = sub.isPro;
        final child = Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.ember.withValues(alpha: active ? 0.26 : 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  active ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                  color: AppColors.ember,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'QuickScanner',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.snow),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.ultraGold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            active ? 'Pro active' : 'Pro',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      active
                          ? 'OCR, unlimited pages, cloud backup, and AI rename are unlocked.'
                          : 'Unlock OCR, unlimited pages, cloud backup, and AI smart rename.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                active ? Icons.check_rounded : Icons.chevron_right_rounded,
                color: AppColors.mist,
              ),
            ],
          ),
        );

        return Material(
          color: AppColors.graphite,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            onTap: active ? null : onUnlockTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.stroke),
                gradient: LinearGradient(
                  colors: [
                    AppColors.ember.withValues(alpha: active ? 0.06 : 0.12),
                    AppColors.graphite,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
