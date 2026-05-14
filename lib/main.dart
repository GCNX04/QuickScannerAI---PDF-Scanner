import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/security/app_lifecycle_lock.dart';
import 'core/security/app_lock_service.dart';
import 'core/security/vault_keys.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/onboarding_prefs.dart';
import 'services/scan_storage.dart';
import 'services/subscription_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_overlay_layer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final subscription = SubscriptionService();
  await subscription.initialize();
  await VaultKeys.instance.ensureInitialized();
  await ScanStorage.migrateLegacyPlaintextArtifacts();
  await subscription.loadSubscriptionStatus();
  await AppLockService.instance.loadPreferences();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  List<CameraDescription> cameras = const <CameraDescription>[];
  try {
    cameras = await availableCameras();
  } catch (_) {
    cameras = const <CameraDescription>[];
  }

  runApp(
    ChangeNotifierProvider<SubscriptionService>.value(
      value: subscription,
      child: AppLifecycleLock(
        child: QuickScannerApp(cameras: cameras),
      ),
    ),
  );
}

class QuickScannerApp extends StatelessWidget {
  const QuickScannerApp({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickScanner AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      builder: (context, child) => AppLockOverlayLayer(child: child),
      home: _LaunchRouter(cameras: cameras),
    );
  }
}

class _LaunchRouter extends StatefulWidget {
  const _LaunchRouter({required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<_LaunchRouter> createState() => _LaunchRouterState();
}

class _LaunchRouterState extends State<_LaunchRouter> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final done = await OnboardingPrefs.hasCompleted();
    if (!mounted) return;
    setState(() => _onboardingDone = done);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const Scaffold(
        backgroundColor: AppColors.voidBlack,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.ember),
        ),
      );
    }
    if (_onboardingDone!) {
      return HomeScreen(cameras: widget.cameras);
    }
    return OnboardingScreen(cameras: widget.cameras);
  }
}
