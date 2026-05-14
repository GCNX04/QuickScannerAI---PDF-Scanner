import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

/// Full-screen premium upsell (RevenueCat + store products when configured).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> with TickerProviderStateMixin {
  static const double _monthly = 6.99;
  static const double _yearly = 39.99;

  Package? _monthlyPkg;
  Package? _annualPkg;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final Animation<double> _glow = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);

  _PlanChoice _selected = _PlanChoice.yearly;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      if (await Purchases.isConfigured) {
        final offerings = await Purchases.getOfferings();
        final current = offerings.current;
        Package? m;
        Package? a;
        if (current != null) {
          for (final p in current.availablePackages) {
            if (p.packageType == PackageType.monthly) m ??= p;
            if (p.packageType == PackageType.annual) a ??= p;
          }
          for (final p in current.availablePackages) {
            final blob = '${p.identifier} ${p.storeProduct.identifier}'.toLowerCase();
            if (m == null && (blob.contains('month') || blob.contains('1m'))) {
              m = p;
            }
            if (a == null && (blob.contains('year') || blob.contains('annual') || blob.contains('1y'))) {
              a = p;
            }
          }
        }
        if (mounted) {
          setState(() {
            _monthlyPkg = m;
            _annualPkg = a;
          });
        }
      }
    } catch (_) {
      // Keep fallback display prices.
    }
    if (mounted) setState(() {});
  }

  String get _monthlyPriceLabel =>
      _monthlyPkg?.storeProduct.priceString ?? '\$${_monthly.toStringAsFixed(2)}';

  String get _yearlyPriceLabel =>
      _annualPkg?.storeProduct.priceString ?? '\$${_yearly.toStringAsFixed(2)}';

  int get _savePercent {
    final mp = _monthlyPkg?.storeProduct.price ?? _monthly;
    final yp = _annualPkg?.storeProduct.price ?? _yearly;
    final annualIfMonthly = mp * 12;
    if (annualIfMonthly <= 0) return 40;
    final off = ((annualIfMonthly - yp) / annualIfMonthly * 100).round();
    return off.clamp(0, 99);
  }

  String? get _yearlyIntroLabel {
    final intro = _annualPkg?.storeProduct.introductoryPrice;
    if (intro == null) return null;
    return 'Intro offer from the store when you qualify (${intro.priceString}).';
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _purchaseSelected() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final sub = context.read<SubscriptionService>();
      final type = _selected == _PlanChoice.yearly ? PackageType.annual : PackageType.monthly;
      final r = await sub.purchasePackage(type);
      if (!mounted) return;
      if (r.unlocked) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop(true);
        return;
      }
      if (!r.cancelled && r.errorMessage != null && r.errorMessage!.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(r.errorMessage!),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
          ),
        );
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
      final ok = await context.read<SubscriptionService>().restorePurchases();
      if (!mounted) return;
      if (ok) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No active subscription found. Use the same Google Play account you purchased with, then try again.',
            ),
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
                          priceLabel: _monthlyPriceLabel,
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
                          priceLabel: _yearlyPriceLabel,
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
                          _yearlyIntroLabel ??
                              'Free trials and intro offers, when available, are applied by Google Play at checkout. Yearly plans often include trials (commonly ${SubscriptionService.trialDaysHint} days) when configured by the publisher.',
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
                        onPressed: _busy ? null : _purchaseSelected,
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
                                    ? 'Subscribe yearly'
                                    : 'Subscribe monthly',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selected = _selected == _PlanChoice.yearly
                                    ? _PlanChoice.monthly
                                    : _PlanChoice.yearly;
                              });
                            },
                      child: Text(
                        _selected == _PlanChoice.yearly
                            ? 'Prefer monthly?'
                            : 'Switch to yearly — save $_savePercent%',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (!context.watch<SubscriptionService>().isRevenueCatConfigured) ...[
                      const SizedBox(height: 8),
                      Text(
                        'This build is missing RevenueCat API keys — purchases are disabled. See docs/REVENUECAT_SETUP.md.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.ember),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Subscriptions renew until canceled in your Google Play account settings.',
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
