import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/premium_service.dart';
import '../theme/app_theme.dart';

/// Full-screen premium upsell with mock checkout (swap for StoreKit / Play Billing).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> with TickerProviderStateMixin {
  static const double _monthly = 6.99;
  static const double _yearly = 39.99;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final Animation<double> _glow = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);

  _PlanChoice _selected = _PlanChoice.yearly;
  bool _busy = false;

  int get _savePercent {
    final annualIfMonthly = _monthly * 12;
    final off = ((annualIfMonthly - _yearly) / annualIfMonthly * 100).round();
    return off.clamp(0, 99);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await action();
      if (!mounted) return;
      if (PremiumService.instance.isEntitled) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    try {
      final ok = await PremiumService.instance.restorePurchases();
      if (!mounted) return;
      if (ok) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No purchases found to restore (mock billing).'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: AnimatedBuilder(
              animation: _glow,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.35 + _glow.value * 0.25,
                  child: child,
                );
              },
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.ember.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -40,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.ultraGold.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: top + 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _busy ? null : () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close_rounded, color: AppColors.mist),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _busy ? null : _restore,
                        child: const Text('Restore purchases'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                sliver: SliverToBoxAdapter(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - t)),
                        child: child,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.ember.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.ember.withValues(alpha: 0.35)),
                              ),
                              child: const Icon(Icons.workspace_premium_rounded, color: AppColors.ember, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'QuickScanner Pro',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.6,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'OCR, smart tools, and cloud peace of mind.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        _FeatureLine(icon: Icons.document_scanner_rounded, label: 'Unlimited pages per scan'),
                        _FeatureLine(icon: Icons.text_fields_rounded, label: 'Text recognition (OCR)'),
                        _FeatureLine(icon: Icons.cloud_done_rounded, label: 'Encrypted cloud backup'),
                        _FeatureLine(icon: Icons.auto_awesome_rounded, label: 'AI smart rename'),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: _PlanCard(
                          title: 'Monthly',
                          priceLabel: '\$${_monthly.toStringAsFixed(2)}',
                          period: '/ month',
                          selected: _selected == _PlanChoice.monthly,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selected = _PlanChoice.monthly);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlanCard(
                          title: 'Yearly',
                          priceLabel: '\$${_yearly.toStringAsFixed(2)}',
                          period: '/ year',
                          badge: 'Save $_savePercent%',
                          selected: _selected == _PlanChoice.yearly,
                          highlight: true,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selected = _PlanChoice.yearly);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 18, color: AppColors.ultraGold.withValues(alpha: 0.95)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${PremiumService.trialDays}-day free trial on yearly — cancel anytime.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.fog),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.voidBlack.withValues(alpha: 0),
                      AppColors.voidBlack.withValues(alpha: 0.92),
                      AppColors.voidBlack,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: FilledButton(
                        key: ValueKey(_selected),
                        onPressed: _busy
                            ? null
                            : () {
                                if (_selected == _PlanChoice.yearly) {
                                  _run(PremiumService.instance.startFreeTrial);
                                } else {
                                  _run(PremiumService.instance.purchaseMonthly);
                                }
                              },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: _busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : Text(
                                _selected == _PlanChoice.yearly
                                    ? 'Start ${PremiumService.trialDays}-day free trial'
                                    : 'Subscribe for \$${_monthly.toStringAsFixed(2)}/mo',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              if (_selected == _PlanChoice.yearly) {
                                _run(PremiumService.instance.purchaseYearly);
                              } else {
                                setState(() => _selected = _PlanChoice.yearly);
                                _run(PremiumService.instance.startFreeTrial);
                              }
                            },
                      child: Text(
                        _selected == _PlanChoice.yearly
                            ? 'Skip trial — subscribe yearly now'
                            : 'Try yearly with ${PremiumService.trialDays}-day trial',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mock billing — no charges. Replace with in-app purchases when ready.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.mist),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PlanChoice { monthly, yearly }

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.graphiteElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Icon(icon, size: 18, color: AppColors.ember),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.snow, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: AppColors.ultraGold, size: 22),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.priceLabel,
    required this.period,
    required this.selected,
    required this.onTap,
    this.badge,
    this.highlight = false,
  });

  final String title;
  final String priceLabel;
  final String period;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.02 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: selected && highlight
                  ? LinearGradient(
                      colors: [
                        AppColors.ember.withValues(alpha: 0.22),
                        AppColors.graphite,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: selected && !highlight ? AppColors.graphiteElevated : AppColors.graphite,
              border: Border.all(
                color: selected ? AppColors.ember : AppColors.stroke,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected ? AppShadows.cardLift(AppColors.ember) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: selected ? AppColors.snow : AppColors.mist,
                        fontSize: 15,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.ultraGold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: AppColors.snow,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        period,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
