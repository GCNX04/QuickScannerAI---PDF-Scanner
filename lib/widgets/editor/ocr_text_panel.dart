import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/secure_file_wipe.dart';

import '../../services/premium_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/paywall_navigation.dart';
import '../../widgets/qs_snackbar.dart';

/// Per-page OCR pipeline state shown in the Text tab.
enum QsOcrJobState {
  idle,
  loading,
  ready,
  error,
}

/// Multi-page OCR workspace: ML Kit output, search, copy/share/export (premium).
class OcrTextPanel extends StatefulWidget {
  const OcrTextPanel({
    super.key,
    required this.pageCount,
    required this.segment,
    required this.onSegment,
    required this.jobStates,
    required this.pageTexts,
    required this.isPremium,
    required this.onPageTextChanged,
    required this.onRefresh,
  });

  final int pageCount;
  /// Selected page index, or `-1` for combined view (read-only).
  final int segment;
  final ValueChanged<int> onSegment;
  final List<QsOcrJobState> jobStates;
  final List<String> pageTexts;
  final bool isPremium;
  final void Function(int pageIndex, String text) onPageTextChanged;
  final VoidCallback onRefresh;

  @override
  State<OcrTextPanel> createState() => _OcrTextPanelState();
}

class _OcrTextPanelState extends State<OcrTextPanel> {
  late final TextEditingController _search = TextEditingController();
  late final TextEditingController _editor = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncEditor();
    _search.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant OcrTextPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segment != widget.segment ||
        !listEquals(oldWidget.pageTexts, widget.pageTexts) ||
        !listEquals(oldWidget.jobStates, widget.jobStates) ||
        oldWidget.isPremium != widget.isPremium) {
      _syncEditor();
    }
  }

  void _syncEditor() {
    final t = _activeBody();
    if (_editor.text != t) {
      _editor.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length.clamp(0, 1 << 20)),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _editor.dispose();
    super.dispose();
  }

  String _combined() {
    final b = StringBuffer();
    for (var i = 0; i < widget.pageTexts.length; i++) {
      if (i > 0) b.writeln('\n');
      b.writeln('--- Page ${i + 1} ---');
      b.writeln(widget.pageTexts[i].trimRight());
    }
    return b.toString().trimRight();
  }

  String _fullActiveText() {
    if (widget.segment == -1) return _combined();
    if (widget.segment < 0 || widget.segment >= widget.pageTexts.length) return '';
    return widget.pageTexts[widget.segment];
  }

  String _activeBody() {
    final full = _fullActiveText();
    if (widget.isPremium) return full;
    if (full.length <= PremiumService.ocrPreviewCharacterLimit) return full;
    return full.substring(0, PremiumService.ocrPreviewCharacterLimit);
  }

  String _exportableForActions() => _activeBody();

  Iterable<String> _searchHits() {
    final q = _search.text.trim();
    if (q.isEmpty) return const [];
    final hay = _exportableForActions().toLowerCase();
    final needle = q.toLowerCase();
    final hits = <String>[];
    var start = 0;
    while (true) {
      final i = hay.indexOf(needle, start);
      if (i < 0) break;
      final from = (i - 24).clamp(0, hay.length);
      final to = (i + needle.length + 48).clamp(0, hay.length);
      hits.add(_exportableForActions().substring(from, to).replaceAll('\n', ' '));
      start = i + needle.length;
      if (hits.length >= 24) break;
    }
    return hits;
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _exportableForActions()));
    if (!mounted) return;
    QsMessenger.success(context, widget.isPremium ? 'Text copied.' : 'Preview copied.');
  }

  Future<void> _share() async {
    await Share.share(_exportableForActions(), subject: 'QuickScanner OCR');
  }

  Future<void> _exportFile() async {
    if (!widget.isPremium) {
      await openPaywall(context);
      return;
    }
    File? f;
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      f = File('${dir.path}/quickscanner_ocr_$stamp.txt');
      await f.writeAsString(_combined(), flush: true);
      if (!mounted) return;
      await Share.shareXFiles([XFile(f.path)], subject: 'OCR export');
    } catch (e) {
      if (mounted) {
        QsMessenger.error(
          context,
          kReleaseMode ? 'Export failed.' : 'Export failed: $e',
        );
      }
    } finally {
      if (f != null) {
        await secureDeleteFile(f);
      }
    }
  }

  bool get _anyLoading => widget.jobStates.any((s) => s == QsOcrJobState.loading);

  @override
  Widget build(BuildContext context) {
    final segments = <ButtonSegment<int>>[
      for (var i = 0; i < widget.pageCount; i++) ButtonSegment<int>(value: i, label: Text('${i + 1}')),
      const ButtonSegment<int>(value: -1, label: Text('All')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Icon(Icons.text_fields_rounded, color: AppColors.ember.withValues(alpha: 0.9), size: 22),
              const SizedBox(width: 8),
              Text(
                'Recognized text',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.snow,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh OCR',
                onPressed: _anyLoading ? null : widget.onRefresh,
                icon: _anyLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ember),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppColors.mist),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: segments,
              selected: {widget.segment.clamp(-1, widget.pageCount - 1)},
              onSelectionChanged: (s) {
                final v = s.first;
                widget.onSegment(v);
                setState(_syncEditor);
              },
            ),
          ),
        ),
        if (!widget.isPremium)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.ember.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.ember.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_rounded, color: AppColors.ember, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Preview (${PremiumService.ocrPreviewCharacterLimit} chars). Upgrade for full text, edit, and file export.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => openPaywall(context),
                    child: const Text('Pro'),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: TextField(
            controller: _search,
            style: const TextStyle(color: AppColors.snow),
            decoration: InputDecoration(
              hintText: 'Search in text…',
              hintStyle: TextStyle(color: AppColors.mist.withValues(alpha: 0.8)),
              filled: true,
              fillColor: AppColors.graphiteElevated,
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.mist),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.stroke)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.stroke)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.ember, width: 1.4),
              ),
            ),
          ),
        ),
        if (_search.text.trim().isNotEmpty)
          SizedBox(
            height: 88,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              children: [
                Text(
                  '${_searchHits().length} match(es)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.mist),
                ),
                const SizedBox(height: 6),
                ..._searchHits().map(
                  (h) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('… $h …', style: const TextStyle(color: AppColors.fog, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _copy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _share,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Share'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _exportFile,
                icon: const Icon(Icons.save_alt_rounded, size: 18),
                label: const Text('Export .txt'),
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _body(context),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final combinedEmpty = widget.pageTexts.every((t) => t.trim().isEmpty);
    final anyLoading = widget.jobStates.any((s) => s == QsOcrJobState.loading);
    if (combinedEmpty && anyLoading) {
      return const _OcrSkeletonList(key: ValueKey('sk_all'));
    }
    if (widget.segment >= 0 &&
        widget.segment < widget.jobStates.length &&
        widget.jobStates[widget.segment] == QsOcrJobState.loading &&
        widget.pageTexts[widget.segment].isEmpty) {
      return const _OcrSkeletonList(key: ValueKey('sk'));
    }
    if (_fullActiveText().isEmpty &&
        widget.segment >= 0 &&
        widget.jobStates[widget.segment] == QsOcrJobState.idle) {
      return Center(
        key: const ValueKey('empty'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'OCR will start automatically. Tap refresh if this stays empty.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final readOnly = widget.segment == -1 || !widget.isPremium;
    return Padding(
      key: ValueKey('${widget.segment}|${widget.isPremium}'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.graphiteElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.stroke),
        ),
        child: TextField(
          controller: _editor,
          maxLines: null,
          expands: true,
          readOnly: readOnly,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(color: AppColors.snow, height: 1.45, fontSize: 14),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.all(14),
            border: InputBorder.none,
          ),
          onChanged: readOnly
              ? null
              : (v) {
                  if (widget.segment >= 0) widget.onPageTextChanged(widget.segment, v);
                },
        ),
      ),
    );
  }
}

class _OcrSkeletonList extends StatelessWidget {
  const _OcrSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: List.generate(
          5,
          (i) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.35, end: 1),
            duration: Duration(milliseconds: 900 + i * 120),
            curve: Curves.easeInOut,
            builder: (context, v, child) => Opacity(
              opacity: 0.25 + 0.55 * (0.5 + 0.5 * (1 - (v - 0.5).abs() * 2)),
              child: child,
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.graphite,
                  borderRadius: BorderRadius.circular(8),
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
