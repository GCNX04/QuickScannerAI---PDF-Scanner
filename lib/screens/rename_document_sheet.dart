import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../utils/paywall_navigation.dart';

class RenameDocumentSheet extends StatefulWidget {
  const RenameDocumentSheet({
    super.key,
    required this.initialName,
    this.suggestedNames = const [],
    this.previewSuggestionsOnly = false,
  });

  final String initialName;
  final List<String> suggestedNames;
  final bool previewSuggestionsOnly;

  @override
  State<RenameDocumentSheet> createState() => _RenameDocumentSheetState();
}

class _RenameDocumentSheetState extends State<RenameDocumentSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Consumer<SubscriptionService>(
      builder: (context, sub, _) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 14),
                child: child,
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + bottom),
              decoration: BoxDecoration(
                color: AppColors.graphite,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(color: AppColors.stroke),
                boxShadow: AppShadows.cardLift(AppColors.ember),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.graphiteElevated,
                          foregroundColor: AppColors.snow,
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Expanded(
                        child: Text(
                          'Rename',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context, _controller.text.trim());
                        },
                        child: const Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    style: const TextStyle(color: AppColors.snow, fontWeight: FontWeight.w700),
                    cursorColor: AppColors.ember,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.graphiteElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.stroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.ember, width: 1.6),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => _controller.clear(),
                        icon: const Icon(Icons.clear_rounded, color: AppColors.mist),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (widget.previewSuggestionsOnly) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.graphiteElevated,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart name preview',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in widget.suggestedNames.take(2))
                                _SuggestionChip(label: s, onTap: () => _applySuggestion(s)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                await openPaywall(context);
                              },
                              child: const Text('Unlock full AI-style names'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (sub.isPro) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.graphiteElevated,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI name ideas',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in widget.suggestedNames.take(8))
                                _SuggestionChip(label: s, onTap: () => _applySuggestion(s)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.graphiteElevated,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unlock smart name suggestions',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                await openPaywall(context);
                              },
                              child: const Text('Upgrade to Pro'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _DateChip(label: 'Today', onTap: () => _applyDate(DateTime.now())),
                        _DateChip(
                          label: 'Yesterday',
                          onTap: () => _applyDate(DateTime.now().subtract(const Duration(days: 1))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _applySuggestion(String s) {
    HapticFeedback.selectionClick();
    setState(() => _controller.text = s);
  }

  void _applyDate(DateTime d) {
    final label =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    setState(() => _controller.text = label);
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.graphite,
      side: const BorderSide(color: AppColors.ember, width: 1.2),
      labelStyle: const TextStyle(color: AppColors.snow, fontWeight: FontWeight.w800, fontSize: 13),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: AppColors.graphiteElevated,
        side: const BorderSide(color: AppColors.stroke),
        labelStyle: const TextStyle(color: AppColors.snow, fontWeight: FontWeight.w700),
      ),
    );
  }
}
