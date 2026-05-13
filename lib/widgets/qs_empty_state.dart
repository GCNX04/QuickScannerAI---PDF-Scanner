import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QsEmptyState extends StatelessWidget {
  const QsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.92, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(140, 100),
                    painter: _EmptyDocsIllustrationPainter(
                      accent: AppColors.ember.withValues(alpha: 0.35),
                      stroke: AppColors.stroke,
                    ),
                  ),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.graphite.withValues(alpha: 0.82),
                      border: Border.all(color: AppColors.stroke),
                      boxShadow: AppShadows.cardLift(AppColors.ember),
                    ),
                    child: Icon(icon, size: 40, color: AppColors.ember.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyDocsIllustrationPainter extends CustomPainter {
  _EmptyDocsIllustrationPainter({required this.accent, required this.stroke});

  final Color accent;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx - 18, cy + 6), width: 72, height: 52),
      const Radius.circular(10),
    );
    final r2 = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + 18, cy - 4), width: 72, height: 52),
      const Radius.circular(10),
    );
    final fill = Paint()..color = accent;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = stroke;
    canvas.drawRRect(r, fill);
    canvas.drawRRect(r, border);
    canvas.drawRRect(r2, fill);
    canvas.drawRRect(r2, border);
  }

  @override
  bool shouldRepaint(covariant _EmptyDocsIllustrationPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.stroke != stroke;
}
