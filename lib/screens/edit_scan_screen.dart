import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/document_insights.dart';
import '../services/image_page_processor.dart';
import '../services/isolate_filter_thumb.dart';
import '../services/ocr/document_text_analysis.dart';
import '../services/ocr/mlkit_ocr_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_routes.dart';
import '../widgets/editor/ocr_text_panel.dart';
import '../widgets/editor/smart_data_panel.dart';
import '../widgets/premium_badge.dart';
import '../widgets/qs_pressable.dart';
import '../widgets/qs_snackbar.dart';
import 'export_scan_screen.dart';
import 'rename_document_sheet.dart';

class EditablePage {
  EditablePage(this.original);

  Uint8List original;
  int rotationQuarterTurns = 0;
  ScanFilter filter = ScanFilter.auto;
}

class EditScanScreen extends StatefulWidget {
  const EditScanScreen({
    super.key,
    required this.pages,
    this.initialTitle,
  });

  final List<Uint8List> pages;
  final String? initialTitle;

  @override
  State<EditScanScreen> createState() => _EditScanScreenState();
}

class _EditScanScreenState extends State<EditScanScreen> with TickerProviderStateMixin {
  late final List<EditablePage> _pages = widget.pages.map(EditablePage.new).toList();
  late final TabController _tabs = TabController(length: 3, vsync: this);
  int _index = 0;
  bool _curvature = false;
  late String _title = widget.initialTitle ?? _defaultTitle();
  final Map<String, Uint8List> _previewCache = {};
  final Map<String, Future<Uint8List>> _filterThumbFutures = {};

  final MlKitOcrService _ocrSvc = MlKitOcrService();
  late List<String> _ocrByPage;
  late List<QsOcrJobState> _ocrJobStates;
  int _ocrSegment = 0;
  DocumentInsights? _insights;
  bool _insightsLoading = false;
  Timer? _insightsDebounce;

  EditablePage get _current => _pages[_index];

  String _defaultTitle() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  void _invalidateFilterThumbs() => _filterThumbFutures.clear();

  Future<Uint8List> _filterThumbFuture(ScanFilter f) {
    final p = _pages[_index];
    final key = '$_index|${p.rotationQuarterTurns}|$_curvature|${f.index}|${p.original.hashCode}';
    return _filterThumbFutures.putIfAbsent(
      key,
      () => compute(buildFilterThumbIsolate, <String, dynamic>{
            'b': p.original,
            'r': p.rotationQuarterTurns,
            'f': f.index,
            'c': _curvature,
            't': 88,
          }),
    );
  }

  String _cacheKey(int i) =>
      '$i|${_pages[i].rotationQuarterTurns}|${_pages[i].filter}|$_curvature';

  Uint8List _previewFor(int i) {
    final p = _pages[i];
    final key = _cacheKey(i);
    return _previewCache.putIfAbsent(
      key,
      () => ImagePageProcessor.render(
        originalJpegBytes: p.original,
        rotationQuarterTurns: p.rotationQuarterTurns,
        filter: p.filter,
        curvatureCorrection: _curvature,
      ),
    );
  }

  void _invalidatePreview(int i) {
    _previewCache.removeWhere((k, _) => k.startsWith('$i|'));
  }

  void _onTabs() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index == 2) {
      _scheduleInsightsRefresh();
    }
  }

  Uint8List _renderBytesForOcr(int pageIndex) {
    final p = _pages[pageIndex];
    return ImagePageProcessor.render(
      originalJpegBytes: p.original,
      rotationQuarterTurns: p.rotationQuarterTurns,
      filter: p.filter,
      curvatureCorrection: _curvature,
    );
  }

  String _combinedOcr() {
    final b = StringBuffer();
    for (var i = 0; i < _ocrByPage.length; i++) {
      if (i > 0) b.writeln('\n');
      b.writeln('--- Page ${i + 1} ---');
      b.writeln(_ocrByPage[i].trimRight());
    }
    return b.toString().trimRight();
  }

  void _scheduleInsightsRefresh() {
    _insightsDebounce?.cancel();
    _insightsDebounce = Timer(const Duration(milliseconds: 420), () {
      _recomputeInsights();
    });
  }

  Future<void> _recomputeInsights() async {
    final corpus = _combinedOcr();
    if (corpus.trim().length < 4) {
      if (mounted) {
        setState(() {
          _insights = null;
          _insightsLoading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _insightsLoading = true);
    try {
      final map = await compute(analyzeDocumentTextIsolate, corpus);
      if (!mounted) return;
      setState(() {
        _insights = DocumentInsights.fromMap(map);
        _insightsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _insightsLoading = false);
    }
  }

  Future<void> _runOcrForPage(int i, {bool bypassCache = false}) async {
    if (!mounted || i < 0 || i >= _pages.length) return;
    if (_ocrJobStates[i] == QsOcrJobState.loading) return;
    setState(() => _ocrJobStates[i] = QsOcrJobState.loading);
    try {
      final bytes = _renderBytesForOcr(i);
      final text = await _ocrSvc.recognizeJpegBytes(bytes, bypassCache: bypassCache);
      if (!mounted) return;
      setState(() {
        _ocrByPage[i] = text;
        _ocrJobStates[i] = QsOcrJobState.ready;
      });
      _scheduleInsightsRefresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocrByPage[i] = 'OCR error: $e';
        _ocrJobStates[i] = QsOcrJobState.error;
      });
    }
  }

  Future<void> _kickOcrPipeline({bool bypassCache = false}) async {
    for (var i = 0; i < _pages.length; i++) {
      await _runOcrForPage(i, bypassCache: bypassCache);
    }
  }

  @override
  void initState() {
    super.initState();
    _ocrByPage = List<String>.filled(_pages.length, '');
    _ocrJobStates = List<QsOcrJobState>.filled(_pages.length, QsOcrJobState.idle);
    _tabs.addListener(_onTabs);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_kickOcrPipeline());
    });
  }

  @override
  void dispose() {
    _insightsDebounce?.cancel();
    _tabs.removeListener(_onTabs);
    _tabs.dispose();
    unawaited(_ocrSvc.dispose());
    super.dispose();
  }

  Future<void> _openRename() async {
    HapticFeedback.lightImpact();
    var suggestions = <String>[];
    try {
      final corpus = _combinedOcr();
      if (corpus.trim().length >= 12) {
        final map = await compute(analyzeDocumentTextIsolate, corpus);
        suggestions = DocumentInsights.fromMap(map).nameIdeas;
      }
    } catch (_) {}
    if (suggestions.isEmpty) {
      suggestions = [_defaultTitle(), 'Scan_notes', 'My document'];
    }
    if (!mounted) return;
    final next = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 420),
        reverseDuration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (context) => RenameDocumentSheet(
        initialName: _title,
        suggestedNames: suggestions,
        previewSuggestionsOnly: !PremiumService.instance.hasFullDocumentIntelligence,
      ),
    );
    if (next != null && next.trim().isNotEmpty) {
      setState(() => _title = next.trim());
    }
  }

  Future<void> _reorderPages() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.graphite,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 420),
        reverseDuration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (context) {
        final local = List<EditablePage>.from(_pages);
        final maxH = MediaQuery.sizeOf(context).height * 0.55;
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.stroke,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Reorder pages',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: maxH.clamp(220, 480),
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      itemCount: local.length,
                      onReorder: (a, b) {
                        setModal(() {
                          if (b > a) b -= 1;
                          final item = local.removeAt(a);
                          local.insert(b, item);
                        });
                      },
                      itemBuilder: (context, i) {
                        return ListTile(
                          key: ValueKey('${local[i].original.hashCode}_$i'),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              local[i].original,
                              width: 40,
                              height: 52,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text('Page ${i + 1}'),
                          trailing: const Icon(Icons.drag_handle_rounded, color: AppColors.mist),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _pages
                              ..clear()
                              ..addAll(local);
                            _index = _index.clamp(0, _pages.length - 1);
                            _ocrSegment = _ocrSegment.clamp(0, _pages.length - 1);
                            _previewCache.clear();
                            _invalidateFilterThumbs();
                            _ocrByPage = List.filled(_pages.length, '');
                            _ocrJobStates = List.filled(_pages.length, QsOcrJobState.idle);
                            _insights = null;
                          });
                          Navigator.pop(context);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) unawaited(_kickOcrPipeline());
                          });
                        },
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _rotate(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _current.rotationQuarterTurns = (_current.rotationQuarterTurns + delta) % 4;
      _invalidatePreview(_index);
      _invalidateFilterThumbs();
      _ocrByPage[_index] = '';
      _ocrJobStates[_index] = QsOcrJobState.idle;
      _insights = null;
    });
    unawaited(_runOcrForPage(_index, bypassCache: true));
  }

  void _recrop() {
    HapticFeedback.mediumImpact();
    setState(() {
      _current.original = ImagePageProcessor.trimMargins(_current.original);
      _invalidatePreview(_index);
      _invalidateFilterThumbs();
      _ocrByPage[_index] = '';
      _ocrJobStates[_index] = QsOcrJobState.idle;
      _insights = null;
    });
    unawaited(_runOcrForPage(_index, bypassCache: true));
  }

  void _deletePage() {
    if (_pages.length <= 1) {
      QsMessenger.info(context, 'Keep at least one page.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _pages.removeAt(_index);
      _ocrByPage.removeAt(_index);
      _ocrJobStates.removeAt(_index);
      _index = _index.clamp(0, _pages.length - 1);
      _ocrSegment = _ocrSegment.clamp(0, _pages.length - 1);
      _previewCache.clear();
      _invalidateFilterThumbs();
      _insights = null;
    });
  }

  Future<void> _export() async {
    final rendered = <Uint8List>[];
    for (var i = 0; i < _pages.length; i++) {
      rendered.add(
        ImagePageProcessor.render(
          originalJpegBytes: _pages[i].original,
          rotationQuarterTurns: _pages[i].rotationQuarterTurns,
          filter: _pages[i].filter,
          curvatureCorrection: _curvature,
        ),
      );
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final saved = await Navigator.of(context).push<bool>(
      AppPageRoutes.fadeSlide<bool>(
        child: ExportScanScreen(
          pageImages: rendered,
          documentTitle: _title,
        ),
      ),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PremiumService.instance,
      builder: (context, _) {
        return Scaffold(
      backgroundColor: AppColors.voidBlack,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _openRename,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.expand_more_rounded, color: AppColors.mist, size: 22),
            ],
          ),
        ),
        actions: [
          if (PremiumService.instance.isEntitled)
            const Padding(
              padding: EdgeInsets.only(right: 4, top: 10, bottom: 10),
              child: PremiumBadge(compact: true),
            ),
          TextButton(
            onPressed: _export,
            child: const Text(
              'Export',
              style: TextStyle(color: AppColors.ember, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top + kToolbarHeight),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      child: Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: RepaintBoundary(
                          child: InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4,
                            child: Image.memory(
                              _previewFor(_index),
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_pages.length > 1) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        itemCount: _pages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final sel = i == _index;
                          return GestureDetector(
                            onTap: () {
                              if (i == _index) return;
                              HapticFeedback.selectionClick();
                              setState(() {
                                _index = i;
                                _invalidateFilterThumbs();
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel ? AppColors.ember : AppColors.stroke,
                                  width: sel ? 2.4 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.memory(
                                  _previewFor(i),
                                  width: 44,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: _EditPanel(
              tabController: _tabs,
              currentFilter: _current.filter,
              onFilter: (f) {
                setState(() {
                  _current.filter = f;
                  _invalidatePreview(_index);
                  _ocrByPage[_index] = '';
                  _ocrJobStates[_index] = QsOcrJobState.idle;
                  _insights = null;
                });
                unawaited(_runOcrForPage(_index, bypassCache: true));
              },
              curvature: _curvature,
              onCurvature: (v) {
                setState(() {
                  _curvature = v;
                  _previewCache.clear();
                  _invalidateFilterThumbs();
                  for (var i = 0; i < _ocrByPage.length; i++) {
                    _ocrByPage[i] = '';
                    _ocrJobStates[i] = QsOcrJobState.idle;
                  }
                  _insights = null;
                });
                unawaited(_kickOcrPipeline(bypassCache: true));
              },
              filterThumbFuture: _filterThumbFuture,
              onRotateLeft: () => _rotate(-1),
              onRotateRight: () => _rotate(1),
              onRecrop: _recrop,
              onMovePages: _reorderPages,
              onDeletePage: _deletePage,
              ocrTextChild: OcrTextPanel(
                pageCount: _pages.length,
                segment: _ocrSegment,
                onSegment: (s) => setState(() => _ocrSegment = s),
                jobStates: _ocrJobStates,
                pageTexts: _ocrByPage,
                isPremium: PremiumService.instance.hasFullDocumentIntelligence,
                onPageTextChanged: (i, t) => setState(() => _ocrByPage[i] = t),
                onRefresh: () => unawaited(_kickOcrPipeline(bypassCache: true)),
              ),
              smartDataChild: SmartDataPanel(
                insights: _insights,
                loading: _insightsLoading,
                isPremium: PremiumService.instance.hasFullDocumentIntelligence,
                onRefresh: () => unawaited(_recomputeInsights()),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _EditPanel extends StatelessWidget {
  const _EditPanel({
    required this.tabController,
    required this.currentFilter,
    required this.onFilter,
    required this.curvature,
    required this.onCurvature,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onRecrop,
    required this.onMovePages,
    required this.onDeletePage,
    required this.filterThumbFuture,
    required this.ocrTextChild,
    required this.smartDataChild,
  });

  final TabController tabController;
  final ScanFilter currentFilter;
  final ValueChanged<ScanFilter> onFilter;
  final bool curvature;
  final ValueChanged<bool> onCurvature;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onRecrop;
  final VoidCallback onMovePages;
  final VoidCallback onDeletePage;
  final Future<Uint8List> Function(ScanFilter filter) filterThumbFuture;
  final Widget ocrTextChild;
  final Widget smartDataChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: TabBar(
                  controller: tabController,
                  isScrollable: true,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.graphiteElevated,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  labelColor: AppColors.snow,
                  unselectedLabelColor: AppColors.mist,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Image'),
                    Tab(text: 'Text'),
                    Tab(text: 'Smart data'),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.mist),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                _ImageTools(
                  currentFilter: currentFilter,
                  onFilter: onFilter,
                  curvature: curvature,
                  onCurvature: onCurvature,
                  onRotateLeft: onRotateLeft,
                  onRotateRight: onRotateRight,
                  onRecrop: onRecrop,
                  onMovePages: onMovePages,
                  onDeletePage: onDeletePage,
                  filterThumbFuture: filterThumbFuture,
                ),
                ocrTextChild,
                smartDataChild,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageTools extends StatelessWidget {
  const _ImageTools({
    required this.currentFilter,
    required this.onFilter,
    required this.curvature,
    required this.onCurvature,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onRecrop,
    required this.onMovePages,
    required this.onDeletePage,
    required this.filterThumbFuture,
  });

  final ScanFilter currentFilter;
  final ValueChanged<ScanFilter> onFilter;
  final bool curvature;
  final ValueChanged<bool> onCurvature;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onRecrop;
  final VoidCallback onMovePages;
  final VoidCallback onDeletePage;
  final Future<Uint8List> Function(ScanFilter filter) filterThumbFuture;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _BigToolButton(icon: Icons.crop_rotate_rounded, label: 'Recrop', onTap: onRecrop)),
              const SizedBox(width: 10),
              Expanded(child: _BigToolButton(icon: Icons.rotate_left_rounded, label: 'Left', onTap: onRotateLeft)),
              const SizedBox(width: 10),
              Expanded(child: _BigToolButton(icon: Icons.rotate_right_rounded, label: 'Right', onTap: onRotateRight)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Filters',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 102,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: ScanFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final f = ScanFilter.values[i];
                final label = switch (f) {
                  ScanFilter.auto => 'Auto',
                  ScanFilter.bw => 'B&W',
                  ScanFilter.color => 'Color',
                  ScanFilter.photo => 'Photo',
                };
                final selected = currentFilter == f;
                return _FilterThumbCell(
                  label: label,
                  selected: selected,
                  thumbFuture: filterThumbFuture(f),
                  onTap: () => onFilter(f),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _SettingsRow(
            title: 'Curvature correction',
            trailing: Switch(value: curvature, onChanged: onCurvature),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            title: 'Format',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fit',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.unfold_more_rounded, color: AppColors.mist, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BigToolButton(
                  icon: Icons.swap_vert_rounded,
                  label: 'Move page',
                  onTap: onMovePages,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BigToolButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete page',
                  onTap: onDeletePage,
                  danger: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigToolButton extends StatelessWidget {
  const _BigToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? const Color(0xFFFF6B6B) : AppColors.snow;
    return Material(
      color: AppColors.graphiteElevated,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.ember.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: danger ? const Color(0xFFFF6B6B) : AppColors.snow),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterThumbCell extends StatelessWidget {
  const _FilterThumbCell({
    required this.label,
    required this.selected,
    required this.thumbFuture,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Future<Uint8List> thumbFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QsPressable(
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.ember : AppColors.stroke,
                width: selected ? 2.6 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.ember.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FutureBuilder<Uint8List>(
                future: thumbFuture,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const ColoredBox(
                      color: AppColors.voidBlack,
                      child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.mist)),
                    );
                  }
                  if (!snap.hasData) {
                    return const ColoredBox(
                      color: AppColors.voidBlack,
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ember),
                        ),
                      ),
                    );
                  }
                  return RepaintBoundary(
                    child: Image.memory(
                      snap.data!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.snow : AppColors.mist,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.graphiteElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.snow)),
          ),
          trailing,
        ],
      ),
    );
  }
}
