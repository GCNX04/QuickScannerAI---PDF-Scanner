import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../core/security/app_lock_service.dart';

/// Full-screen gate shown while [AppLockService.shouldShowLock] is true.
class AppLockOverlayLayer extends StatelessWidget {
  const AppLockOverlayLayer({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLockService.instance,
      builder: (context, _) {
        final locked = AppLockService.instance.shouldShowLock;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (child != null) child!,
            if (locked) const _LockScaffold(),
          ],
        );
      },
    );
  }
}

class _LockScaffold extends StatelessWidget {
  const _LockScaffold();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.voidBlack,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 56, color: AppColors.ember.withValues(alpha: 0.9)),
              const SizedBox(height: 18),
              Text(
                'QuickScanner AI is locked',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.snow,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Use Face ID, fingerprint, or your device PIN to continue. '
                'Your scans stay encrypted on this device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mist),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => AppLockService.instance.tryUnlock(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
