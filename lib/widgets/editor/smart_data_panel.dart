import 'package:flutter/material.dart';

import '../../models/document_insights.dart';
import '../../theme/app_theme.dart';
import '../../utils/paywall_navigation.dart';

/// Smart extraction + heuristic summary UI (regex / rules, not cloud LLM).
class SmartDataPanel extends StatelessWidget {
  const SmartDataPanel({
    super.key,
    required this.insights,
    required this.loading,
    required this.isPremium,
    required this.onRefresh,
    this.emptyHint,
  });

  final DocumentInsights? insights;
  final bool loading;
  final bool isPremium;
  final VoidCallback onRefresh;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _SmartSkeleton();
    }
    if (!loading && (insights == null || !insights!.hasAnySignal)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_outlined, size: 48, color: AppColors.mist.withValues(alpha: 0.7)),
              const SizedBox(height: 12),
              Text(
                emptyHint ?? 'Run OCR on the Text tab first — smart insights appear here automatically.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh analysis'),
              ),
            ],
          ),
        ),
      );
    }

    final ins = insights!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        Row(
          children: [
            Icon(Icons.hub_rounded, color: AppColors.ultraGold.withValues(alpha: 0.95), size: 22),
            const SizedBox(width: 8),
            Text(
              'Smart insights',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.snow, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Re-run heuristics',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.mist),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Built locally from OCR using patterns — no cloud model.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        _sectionTitle(context, 'AI-style summary'),
        const SizedBox(height: 10),
        ..._summaryBullets(context, ins),
        const SizedBox(height: 18),
        _sectionTitle(context, 'Topics'),
        const SizedBox(height: 10),
        _topicWrap(context, ins),
        const SizedBox(height: 18),
        _sectionTitle(context, 'Extracted fields'),
        const SizedBox(height: 10),
        ..._fieldCards(context, ins),
        if (!isPremium) ...[
          const SizedBox(height: 16),
          _premiumMoreCard(context),
        ],
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String t) {
    return Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.mist, fontWeight: FontWeight.w800));
  }

  List<Widget> _summaryBullets(BuildContext context, DocumentInsights ins) {
    final items = ins.summaryBullets;
    final cap = isPremium ? items.length : items.length.clamp(0, 2);
    return [
      for (var i = 0; i < cap; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PremiumCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.fiber_manual_record, size: 10, color: AppColors.ember),
                const SizedBox(width: 10),
                Expanded(child: Text(items[i], style: const TextStyle(color: AppColors.snow, height: 1.4))),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _topicWrap(BuildContext context, DocumentInsights ins) {
    final topics = ins.topics;
    if (topics.isEmpty) {
      return Text('No strong topic match.', style: Theme.of(context).textTheme.bodySmall);
    }
    final show = isPremium ? topics : topics.take(1).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in show)
          Chip(
            label: Text(t),
            backgroundColor: AppColors.graphiteElevated,
            side: const BorderSide(color: AppColors.stroke),
            labelStyle: const TextStyle(color: AppColors.snow, fontWeight: FontWeight.w700, fontSize: 12),
          ),
      ],
    );
  }

  List<Widget> _fieldCards(BuildContext context, DocumentInsights ins) {
    final rows = <({String label, String value})>[];
    void add(String label, List<String> vs) {
      for (final v in vs.take(2)) {
        rows.add((label: label, value: v));
      }
    }

    add('Total', ins.totals);
    add('Date', ins.dates);
    add('Invoice #', ins.invoiceNumbers);
    add('Email', ins.emails);
    add('Phone', ins.phones);
    add('Address', ins.addresses);
    add('Merchant', ins.merchants);
    add('Important line', ins.importantLines);

    final widgets = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final masked = !isPremium && i >= 3;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PremiumCard(
            onTap: masked ? () => openPaywall(context) : null,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rows[i].label, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        masked ? '••••••••  Unlock Pro' : rows[i].value,
                        style: const TextStyle(color: AppColors.snow, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                if (masked) const Icon(Icons.lock_rounded, color: AppColors.ember, size: 20),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _premiumMoreCard(BuildContext context) {
    return Material(
      color: AppColors.graphiteElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openPaywall(context),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.ember.withValues(alpha: 0.45)),
            gradient: LinearGradient(
              colors: [AppColors.ember.withValues(alpha: 0.12), AppColors.graphiteElevated],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: AppColors.ember),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unlock full smart cards, summaries, and AI rename ideas.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mist),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.graphite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SmartSkeleton extends StatelessWidget {
  const _SmartSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: List.generate(
          6,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.35, end: 1),
              duration: Duration(milliseconds: 700 + i * 90),
              curve: Curves.easeInOut,
              builder: (context, v, child) => Opacity(
                opacity: 0.28 + 0.55 * (0.5 + 0.5 * (1 - (v - 0.5).abs() * 2)),
                child: child,
              ),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.graphiteElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.stroke),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
