import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/require_pro.dart';

/// Shown on the **Smart data** tab when the user does not have entitlement [pro].
class SmartInsightsLockedPanel extends StatelessWidget {
  const SmartInsightsLockedPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 52, color: AppColors.ember.withValues(alpha: 0.85)),
            const SizedBox(height: 16),
            Text(
              'Smart insights',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.snow,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pro unlocks local summaries, topics, and extracted fields from your OCR text.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mist),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () async {
                await requirePro(context);
              },
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text('Unlock with Pro'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
