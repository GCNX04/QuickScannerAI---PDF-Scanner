import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/revenuecat_config.dart';

/// Result of [SubscriptionService.purchasePackage].
typedef PackagePurchaseResult = ({
  bool unlocked,
  bool cancelled,
  String? errorMessage,
});

/// RevenueCat + Google Play subscription state for QuickScanner (Android).
///
/// **Sandbox testing (Google Play):** In Play Console → Settings → License testing, add Gmail
/// accounts as license testers. Upload an AAB to **Internal testing**, install from the Play Store
/// test link, and use a tester account. Purchases use Play Billing test cards; subscriptions renew
/// on accelerated schedules. See also `docs/TESTING_SUBSCRIPTIONS.md`.
///
/// TODO(RevenueCat): Provide your **public** Android SDK key at build time (never commit secrets):
/// `flutter build appbundle --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxxxxxxx`
///
/// TODO(Google Play): Create subscription base plans in Play Console (e.g. monthly + yearly) and
/// register the same product identifiers in RevenueCat → Products, then attach them to the
/// entitlement [pro] and your **Current** offering (Monthly + Annual packages).
class SubscriptionService extends ChangeNotifier {
  SubscriptionService();

  /// Must match the entitlement identifier in RevenueCat (`pro`).
  static const String proEntitlementId = 'pro';

  static const int freePageLimit = 8;
  static const int ocrPreviewCharacterLimit = 480;

  /// Copy-only: store-managed trial length varies; used in paywall helper text.
  static const int trialDaysHint = 7;

  CustomerInfo? _customerInfo;
  bool _initCalled = false;
  bool _sdkConfigured = false;

  CustomerInfo? get customerInfo => _customerInfo;

  /// Whether [Purchases.configure] completed successfully on Android.
  bool get isRevenueCatConfigured => _sdkConfigured;

  /// `true` when the user has an active RevenueCat entitlement (default id `pro`, overridable via
  /// [RevenueCatConfig.entitlementId] / `--dart-define=REVENUECAT_ENTITLEMENT_ID=`).
  bool get isPro {
    final info = _customerInfo;
    if (info == null) return false;
    return info.entitlements.active.containsKey(RevenueCatConfig.entitlementId);
  }

  bool get hasUnlimitedPages => isPro;
  bool get hasFullOcrExport => isPro;
  bool get hasSmartInsights => isPro;
  bool get hasAiSmartRename => isPro;
  bool get hasCloudBackup => isPro;

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _customerInfo = info;
    notifyListeners();
  }

  /// Initializes the RevenueCat SDK on Android. Call once after
  /// [WidgetsFlutterBinding.ensureInitialized].
  Future<void> initialize() async {
    if (_initCalled) return;
    _initCalled = true;

    if (kIsWeb) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isFuchsia) return;
    if (!Platform.isAndroid) return;

    final apiKey = RevenueCatConfig.androidApiKey;
    if (apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'SubscriptionService: missing REVENUECAT_ANDROID_API_KEY — '
          'SDK not configured. Pass --dart-define at build time.',
        );
      }
      return;
    }

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      await Purchases.configure(PurchasesConfiguration(apiKey));
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
      _sdkConfigured = true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SubscriptionService.initialize failed: $e\n$st');
      }
    }
  }

  /// Syncs subscription state from RevenueCat / Play (call on startup and after paywall).
  Future<void> loadSubscriptionStatus() async {
    if (!_sdkConfigured) {
      _customerInfo = null;
      notifyListeners();
      return;
    }
    try {
      _customerInfo = await Purchases.getCustomerInfo();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SubscriptionService.loadSubscriptionStatus: $e\n$st');
      }
    }
    notifyListeners();
  }

  Future<Package?> _packageForType(PackageType type) async {
    if (!_sdkConfigured) return null;
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) return null;

    for (final p in current.availablePackages) {
      if (p.packageType == type) return p;
    }
    for (final p in current.availablePackages) {
      final blob = '${p.identifier} ${p.storeProduct.identifier}'.toLowerCase();
      if (type == PackageType.monthly &&
          (blob.contains('month') || blob.contains('1m'))) {
        return p;
      }
      if (type == PackageType.annual &&
          (blob.contains('year') || blob.contains('annual') || blob.contains('1y'))) {
        return p;
      }
    }
    return null;
  }

  /// Purchases the store package for [packageType] (monthly or annual offering package).
  Future<PackagePurchaseResult> purchasePackage(PackageType packageType) async {
    await loadSubscriptionStatus();
    if (!_sdkConfigured) {
      return (
        unlocked: false,
        cancelled: false,
        errorMessage: 'Billing is not configured. Add REVENUECAT_ANDROID_API_KEY to your build.',
      );
    }

    final pkg = await _packageForType(packageType);
    if (pkg == null) {
      return (
        unlocked: false,
        cancelled: false,
        errorMessage: 'No plans available. Check RevenueCat default offering and Play products.',
      );
    }

    try {
      final result = await Purchases.purchase(PurchaseParams.package(pkg));
      _customerInfo = result.customerInfo;
      notifyListeners();
      return (unlocked: isPro, cancelled: false, errorMessage: isPro ? null : 'Purchase finished but Pro is not active.');
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return (unlocked: false, cancelled: true, errorMessage: null);
      }
      return (
        unlocked: false,
        cancelled: false,
        errorMessage: e.message ?? 'Purchase failed.',
      );
    } catch (e) {
      return (unlocked: false, cancelled: false, errorMessage: e.toString());
    }
  }

  /// Restores transactions with Google Play and refreshes entitlements.
  Future<bool> restorePurchases() async {
    await loadSubscriptionStatus();
    if (!_sdkConfigured) return false;
    try {
      final info = await Purchases.restorePurchases();
      _customerInfo = info;
      notifyListeners();
      return isPro;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('restorePurchases: $e');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('restorePurchases: $e');
      }
      return false;
    }
  }

  /// Debug only: clears the anonymous RevenueCat user when the SDK is configured.
  Future<void> debugResetSubscription() async {
    if (!_sdkConfigured) {
      _customerInfo = null;
      notifyListeners();
      return;
    }
    try {
      if (await Purchases.isConfigured) {
        final info = await Purchases.logOut();
        _customerInfo = info;
      } else {
        _customerInfo = null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('debugResetSubscription: $e');
      }
      _customerInfo = null;
    }
    notifyListeners();
  }
}
