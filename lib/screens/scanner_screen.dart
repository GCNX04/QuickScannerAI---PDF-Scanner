import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../utils/paywall_navigation.dart';
import '../widgets/app_page_routes.dart';
import 'edit_scan_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;
  final List<Uint8List> _pages = [];
  late final AnimationController _shutter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 360),
  );
  late final Animation<double> _shutterOpacity = CurvedAnimation(
    parent: _shutter,
    curve: Curves.easeInOutCubicEmphasized,
    reverseCurve: Curves.easeOutCubic,
  );
  late final AnimationController _borderPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Camera permission is required to scan.';
      });
      return;
    }

    if (widget.cameras.isEmpty) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'No camera is available on this device.';
      });
      return;
    }

    final camera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    final next = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      await _controller?.dispose();
      _controller = next;
      setState(() {
        _initializing = false;
        _error = null;
      });
      _registerVisionPipelineHook(next);
    } catch (e) {
      await next.dispose();
      if (!mounted) return;
      setState(() {
        _controller = null;
        _initializing = false;
        _error = 'Could not start the camera. Try again on a device or emulator with camera support.';
      });
    }
  }

  Future<void> _capturePage() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;

    final sub = context.read<SubscriptionService>();
    if (!sub.hasUnlimitedPages && _pages.length >= SubscriptionService.freePageLimit) {
      HapticFeedback.lightImpact();
      await openPaywall(context);
      if (!mounted) return;
      await sub.loadSubscriptionStatus();
      if (!mounted) return;
      if (!sub.hasUnlimitedPages) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Free scans are limited to ${SubscriptionService.freePageLimit} pages. Upgrade for unlimited.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _capturing = true);
    try {
      final shot = await controller.takePicture();
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      setState(() => _pages.add(Uint8List.fromList(bytes)));
      HapticFeedback.mediumImpact();
      await _shutter.forward(from: 0);
      await _shutter.reverse();
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// Reserved for future document-detection / framing (no image stream yet — saves battery).
  void _registerVisionPipelineHook(CameraController c) {
    if (!c.value.isInitialized) {
      return;
    }
  }

  Future<void> _openEditor() async {
    if (_pages.isEmpty) return;
    HapticFeedback.lightImpact();
    final exported = await Navigator.of(context).push<bool>(
      AppPageRoutes.fadeSlide<bool>(
        child: EditScanScreen(pages: List<Uint8List>.from(_pages)),
      ),
    );
    if (!mounted) return;
    if (exported == true) {
      setState(_pages.clear);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _removePageAt(int index) async {
    setState(() => _pages.removeAt(index));
  }

  @override
  void dispose() {
    _shutter.dispose();
    _borderPulse.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      extendBodyBehindAppBar: true,
      body: _initializing
          ? const Center(child: CircularProgressIndicator(color: AppColors.ember))
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off_rounded, size: 56, color: AppColors.mist),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.snow, height: 1.35),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : controller == null || !controller.value.isInitialized
                  ? const SizedBox.shrink()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: AppColors.voidBlack,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 420),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: KeyedSubtree(
                              key: ObjectKey(controller),
                              child: CameraPreview(controller),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 0.95,
                                  colors: [
                                    Colors.transparent,
                                    AppColors.ember.withValues(alpha: 0.06),
                                    Colors.black.withValues(alpha: 0.42),
                                  ],
                                  stops: const [0.5, 0.78, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                        FadeTransition(
                          opacity: Tween<double>(begin: 0, end: 0.45).animate(_shutterOpacity),
                          child: const ColoredBox(color: Colors.white),
                        ),
                        AnimatedBuilder(
                          animation: _borderPulse,
                          builder: (context, child) {
                            final wave = 0.5 + 0.5 * math.sin(_borderPulse.value * math.pi * 2);
                            final alpha = 0.07 + 0.06 * wave;
                            return IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: alpha),
                                    width: 11,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.fromLTRB(8, topPad + 6, 8, 48),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.72),
                                  Colors.black.withValues(alpha: 0),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.maybePop(context),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                                    foregroundColor: AppColors.snow,
                                  ),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                      ),
                                      child: Text(
                                        '${_pages.length} page${_pages.length == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                          color: AppColors.snow,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_pages.isNotEmpty)
                                  TextButton(
                                    onPressed: _openEditor,
                                    child: const Text(
                                      'Next',
                                      style: TextStyle(
                                        color: AppColors.ember,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(width: 48),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 200,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Text(
                                'Align the document edges, then capture each page.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.snow,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _ScannerBottomChrome(
                            pages: _pages,
                            capturing: _capturing,
                            onCapture: _capturePage,
                            onRemove: _removePageAt,
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _ScannerBottomChrome extends StatelessWidget {
  const _ScannerBottomChrome({
    required this.pages,
    required this.capturing,
    required this.onCapture,
    required this.onRemove,
  });

  final List<Uint8List> pages;
  final bool capturing;
  final VoidCallback onCapture;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: Container(
        color: Colors.black.withValues(alpha: 0.82),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pages.isNotEmpty)
                  SizedBox(
                    height: 82,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      scrollDirection: Axis.horizontal,
                      itemCount: pages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(
                                pages[index],
                                height: 76,
                                width: 58,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: -5,
                              right: -5,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.7),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => onRemove(index),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                else
                  const SizedBox(height: 8),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 22),
                    Expanded(
                      child: Text(
                        capturing ? 'Capturing…' : 'Tap the shutter for each page',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1, end: capturing ? 0.92 : 1),
                      duration: const Duration(milliseconds: 160),
                      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                      child: GestureDetector(
                        onTap: capturing ? null : onCapture,
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.ember.withValues(alpha: 0.45),
                                blurRadius: 22,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.ember,
                            ),
                            child: capturing
                                ? const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 22),
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
