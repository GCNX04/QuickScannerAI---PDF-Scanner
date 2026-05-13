import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QsSectionHeader extends StatelessWidget {
  const QsSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: () async => onAction!(),
            child: Text(
              actionLabel!,
              style: const TextStyle(color: AppColors.ember, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
