import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/crypto/aes_gcm_vault.dart';
import '../core/security/app_lock_service.dart';
import '../models/scan_record.dart';
import '../services/onboarding_prefs.dart';
import '../services/premium_service.dart';
import '../services/scan_storage.dart';
import '../theme/app_theme.dart';
import '../utils/paywall_navigation.dart';
import '../widgets/app_page_routes.dart';
import '../widgets/premium_badge.dart';
import '../widgets/qs_empty_state.dart';
import '../widgets/qs_pro_banner.dart';
import '../widgets/qs_section_header.dart';
import '../widgets/qs_shimmer.dart';
import '../widgets/qs_snackbar.dart';
import '../widgets/qs_stat_card.dart';
import 'onboarding_screen.dart';
import 'privacy_policy_screen.dart';
import 'scanner_screen.dart';
import '../services/secure_file_wipe.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ScanRecord> _recents = [];
  bool _loading = false;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _refreshRecents(showGlobalSpinner: false);
  }

  Future<void> _refreshRecents({bool showGlobalSpinner = true}) async {
    if (showGlobalSpinner) {
      setState(() => _loading = true);
    }
    final list = await ScanStorage.loadRecent();
    if (!mounted) return;
    setState(() {
      _recents = list;
      _loading = false;
    });
  }

  Future<void> _shareScan(ScanRecord r) async {
    final file = File(r.path);
    if (!await file.exists()) {
      await ScanStorage.removeIfMissing(r.path);
      await _refreshRecents(showGlobalSpinner: false);
      if (!mounted) return;
      QsMessenger.info(context, 'That scan file is no longer available.');
      return;
    }
    File? tmp;
    try {
      final enc = await file.readAsBytes();
      final pdf = await AesGcmVault.decryptVaultFileStrict(enc);
      final dir = await getTemporaryDirectory();
      final outFile = File('${dir.path}/qs_share_home_${DateTime.now().millisecondsSinceEpoch}.pdf');
      tmp = outFile;
      await outFile.writeAsBytes(pdf, flush: true);
      await Share.shareXFiles([XFile(outFile.path)], subject: r.title);
    } catch (e) {
      if (mounted) {
        QsMessenger.error(
          context,
          kReleaseMode ? 'Could not prepare this scan to share.' : 'Share failed: $e',
        );
      }
    } finally {
      if (tmp != null) {
        await secureDeleteFile(tmp);
      }
    }
  }

  Future<void> _openScanner() async {
    if (widget.cameras.isEmpty) return;
    await Navigator.of(context).push<void>(
      AppPageRoutes.fadeSlide<void>(
        child: ScannerScreen(cameras: widget.cameras),
      ),
    );
    await _refreshRecents(showGlobalSpinner: false);
  }

  Future<void> _openPaywall() async {
    await openPaywall(context);
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 420),
        reverseDuration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          child: ListenableBuilder(
            listenable: AppLockService.instance,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy & security'),
                subtitle: const Text('How we handle your documents'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.fingerprint_rounded),
                title: const Text('App lock (Face ID / fingerprint)'),
                subtitle: Text(
                  AppLockService.instance.biometricLockEnabled
                      ? 'Required when returning from the background.'
                      : 'Off — enable for an extra gate before opening the app.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Switch.adaptive(
                  value: AppLockService.instance.biometricLockEnabled,
                  onChanged: (v) async {
                    await AppLockService.instance.setBiometricLockEnabled(v);
                    if (context.mounted) setState(() {});
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('About QuickScanner AI'),
                subtitle: const Text('Version 1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Manage subscription'),
                subtitle: Text(
                  PremiumService.instance.isEntitled ? 'Pro is active on this device.' : 'Upgrade or restore purchases.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _openPaywall();
                },
              ),
              ListTile(
                leading: const Icon(Icons.replay_rounded),
                title: const Text('Replay onboarding'),
                onTap: () async {
                  Navigator.pop(context);
                  await OnboardingPrefs.reset();
                  if (!context.mounted) return;
                  await Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => OnboardingScreen(cameras: widget.cameras),
                    ),
                  );
                },
              ),
              if (kDebugMode)
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: const Text('Reset subscription (debug)'),
                  onTap: () async {
                    Navigator.pop(context);
                    await PremiumService.instance.debugResetSubscription();
                    if (!context.mounted) return;
                    QsMessenger.info(context, 'Subscription state cleared.');
                  },
                ),
            ],
          ),
        ),
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCamera = widget.cameras.isNotEmpty;
    final greeting = _greeting();
    final mockPages = 18 + _recents.length * 2;
    final mockStorageMb = 240 + _recents.length * 12;

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.voidBlack,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 10),
        child: _ScanFab(onPressed: hasCamera ? _openScanner : null),
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: NavigationBar(
          selectedIndex: _navIndex,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            setState(() => _navIndex = i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_open_outlined),
              selectedIcon: Icon(Icons.folder_rounded),
              label: 'Library',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _navIndex == 0
              ? KeyedSubtree(
                  key: const ValueKey('home_tab'),
                  child: RefreshIndicator(
                    color: AppColors.ember,
                    onRefresh: () => _refreshRecents(showGlobalSpinner: true),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'QuickScanner AI',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                            color: AppColors.mist,
                                            letterSpacing: 1.1,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          greeting,
                                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.6,
                                              ),
                                        ),
                                        if (PremiumService.instance.isEntitled) ...[
                                          const SizedBox(width: 10),
                                          const PremiumBadge(compact: true),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.graphite,
                                    foregroundColor: AppColors.snow,
                                  ),
                                  onPressed: _showSettings,
                                  icon: const Icon(Icons.tune_rounded),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: _HeroScanCard(
                              hasCamera: hasCamera,
                              onScan: _openScanner,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              children: [
                                Expanded(
                                  child: QsStatCard(
                                    icon: Icons.auto_stories_rounded,
                                    label: 'Pages (30d)',
                                    value: mockPages.toString(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: QsStatCard(
                                    icon: Icons.sd_storage_rounded,
                                    label: 'Est. storage',
                                    value: '$mockStorageMb MB',
                                    accent: AppColors.fog,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: QsProBanner(onUnlockTap: _openPaywall),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: QsSectionHeader(
                              title: 'Recent scans',
                              actionLabel: _recents.isNotEmpty ? 'Refresh' : null,
                              onAction: _loading ? null : () => _refreshRecents(showGlobalSpinner: true),
                            ),
                          ),
                        ),
                        if (_loading)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => Padding(
                                  padding: EdgeInsets.only(bottom: index < 5 ? 10 : 0),
                                  child: const _RecentSkeletonTile(),
                                ),
                                childCount: _recents.isEmpty ? 4 : _recents.length.clamp(3, 6),
                              ),
                            ),
                          )
                        else if (_recents.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: QsEmptyState(
                              icon: Icons.folder_open_rounded,
                              title: 'No scans yet',
                              subtitle: hasCamera
                                  ? 'Capture pages with the scanner, polish them in the editor, then export a crisp PDF.'
                                  : 'This device has no camera. Use an emulator with a virtual camera to try scanning.',
                              actionLabel: hasCamera ? 'Scan document' : null,
                              onAction: hasCamera ? _openScanner : null,
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                            sliver: SliverList.separated(
                              itemCount: _recents.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final r = _recents[index];
                                final dt = DateTime.fromMillisecondsSinceEpoch(r.createdMs);
                                return _RecentTile(
                                  record: r,
                                  date: dt,
                                  onOpen: () => _shareScan(r),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('library_tab'),
                  child: _LibraryPane(
                    recents: _recents,
                    loading: _loading,
                    onRefresh: () => _refreshRecents(showGlobalSpinner: true),
                    onOpen: _shareScan,
                  ),
                ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _RecentSkeletonTile extends StatelessWidget {
  const _RecentSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return QsShimmer(
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.graphite,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.stroke),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.graphiteElevated,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 160, decoration: BoxDecoration(color: AppColors.graphiteElevated, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 10),
                  Container(height: 11, width: 120, decoration: BoxDecoration(color: AppColors.graphiteElevated, borderRadius: BorderRadius.circular(6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryPane extends StatelessWidget {
  const _LibraryPane({
    required this.recents,
    required this.loading,
    required this.onRefresh,
    required this.onOpen,
  });

  final List<ScanRecord> recents;
  final bool loading;
  final Future<void> Function() onRefresh;
  final void Function(ScanRecord r) onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const _RecentSkeletonTile(),
      );
    }
    if (recents.isEmpty) {
      return QsEmptyState(
        icon: Icons.library_books_rounded,
        title: 'Library is empty',
        subtitle: 'Saved PDFs will appear here for quick sharing.',
      );
    }
    return RefreshIndicator(
      color: AppColors.ember,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        itemCount: recents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final r = recents[i];
          final dt = DateTime.fromMillisecondsSinceEpoch(r.createdMs);
          return _RecentTile(record: r, date: dt, onOpen: () => onOpen(r));
        },
      ),
    );
  }
}

class _HeroScanCard extends StatelessWidget {
  const _HeroScanCard({required this.hasCamera, required this.onScan});

  final bool hasCamera;
  final Future<void> Function() onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        gradient: LinearGradient(
          colors: [
            AppColors.graphiteElevated,
            AppColors.graphite,
            Color.lerp(AppColors.graphite, AppColors.ember, 0.045)!,
          ],
          stops: const [0.0, 0.62, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.stroke),
        boxShadow: AppShadows.cardLift(AppColors.ember),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.ember.withValues(alpha: 0.18),
                    border: Border.all(color: AppColors.ember.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.document_scanner_rounded, color: AppColors.ember, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan smarter',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Multi-page sessions, premium filters, and instant PDF export.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.mist,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: hasCamera
                    ? () {
                        HapticFeedback.mediumImpact();
                        onScan();
                      }
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_rounded),
                    const SizedBox(width: 10),
                    Text(
                      hasCamera ? 'Scan document' : 'No camera available',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  const _ScanFab({required this.onPressed});

  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.ember.withValues(alpha: 0.45),
            blurRadius: 22,
            spreadRadius: 0,
          ),
        ],
      ),
      child: SizedBox(
        height: 72,
        width: 72,
        child: FloatingActionButton(
          elevation: 10,
          highlightElevation: 14,
          backgroundColor: AppColors.ember,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: enabled
              ? () async {
                  HapticFeedback.mediumImpact();
                  await onPressed?.call();
                }
              : null,
          child: const Icon(Icons.document_scanner_rounded, size: 30),
        ),
      ),
    );
  }
}

class _RecentThumb extends StatefulWidget {
  const _RecentThumb({required this.record});

  final ScanRecord record;

  @override
  State<_RecentThumb> createState() => _RecentThumbState();
}

class _RecentThumbState extends State<_RecentThumb> {
  late final Future<Uint8List?> _thumbFuture = _loadThumb();

  Future<Uint8List?> _loadThumb() async {
    final tp = widget.record.thumbPath;
    if (tp == null) return null;
    final f = File(tp);
    if (!await f.exists()) return null;
    final raw = await f.readAsBytes();
    try {
      return await AesGcmVault.decryptVaultFileStrict(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(
            width: 46,
            height: 58,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.ember.withValues(alpha: 0.7),
                ),
              ),
            ),
          );
        }
        final bytes = snap.data;
        if (bytes != null && bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              bytes,
              width: 46,
              height: 58,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            ),
          );
        }
        return _fallback();
      },
    );
  }

  Widget _fallback() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.ember.withValues(alpha: 0.14),
      ),
      child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.ember),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.record,
    required this.date,
    required this.onOpen,
  });

  final ScanRecord record;
  final DateTime date;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final label =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Material(
      color: AppColors.graphite,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () {
          HapticFeedback.lightImpact();
          onOpen();
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _RecentThumb(record: record),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.snow,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: AppColors.mist.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.ios_share_rounded, color: AppColors.mist),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
