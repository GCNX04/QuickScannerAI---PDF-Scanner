import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/revenuecat_config.dart';

/// Stored subscription tier (derived from RevenueCat [CustomerInfo] when configured).
enum PremiumTier {
  free,
  trial,
  monthly,
  yearly,
}

/// Global subscription + entitlement checks (RevenueCat when API keys are provided).
class PremiumService extends ChangeNotifier {
  PremiumService._();

  static final PremiumService instance = PremiumService._();

  /// Legacy prefs keys (cleared on debug reset; no longer written for tier).
  static const _kTier = 'qs_premium_tier_v1';
  static const _kTrialEnd = 'qs_premium_trial_end_ms_v1';
  static const _kMockReceipt = 'qs_mock_purchase_receipt_v1';

  static const int freePageLimit = 8;
  static const int trialDays = 7;

  PremiumTier _tier = PremiumTier.free;
  int? _trialEndMs;
  bool _loaded = false;
  bool _configureAttempted = false;
  bool _revenueCatEnabled = false;

  PremiumTier get tier => _tier;
  bool get isLoaded => _loaded;

  /// True when [configurePurchasesSdk] successfully called [Purchases.configure].
  bool get isRevenueCatConfigured => _revenueCatEnabled;

  /// Active paid or non-expired trial (from RevenueCat entitlement when enabled).
  bool get isEntitled {
    switch (_tier) {
      case PremiumTier.monthly:
      case PremiumTier.yearly:
        return true;
      case PremiumTier.trial:
        final end = _trialEndMs;
        if (end == null) return false;
        return DateTime.now().millisecondsSinceEpoch < end;
      case PremiumTier.free:
        return false;
    }
  }

  bool get isPaid => _tier == PremiumTier.monthly || _tier == PremiumTier.yearly;

  bool get hasUnlimitedPages => isEntitled;
  bool get hasOcrAccess => isEntitled;
  bool get hasCloudBackup => isEntitled;
  bool get hasAiRename => isEntitled;

  /// Full OCR editing, export, smart cards, and summaries (not just preview).
  bool get hasFullDocumentIntelligence => isEntitled;

  /// Character cap for combined OCR shown to free users (preview).
  static const int ocrPreviewCharacterLimit = 480;

  DateTime? get trialEndsAt =>
      _trialEndMs == null ? null : DateTime.fromMillisecondsSinceEpoch(_trialEndMs!);

  static void _customerInfoListener(CustomerInfo info) {
    instance._applyCustomerInfo(info);
    instance.notifyListeners();
  }

  /// Call once after [WidgetsFlutterBinding.ensureInitialized] (see [main]).
  Future<void> configurePurchasesSdk() async {
    if (_configureAttempted) return;
    _configureAttempted = true;

    if (kIsWeb) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isFuchsia) return;
    if (!Platform.isAndroid) return;

    final apiKey = RevenueCatConfig.androidApiKey.isNotEmpty
        ? RevenueCatConfig.androidApiKey
        : null;

    if (apiKey == null || apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'RevenueCat (Android): missing REVENUECAT_ANDROID_API_KEY — '
          'subscriptions disabled until you pass --dart-define. '
          'See docs/REVENUECAT_SETUP.md.',
        );
      }
      return;
    }

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      await Purchases.configure(PurchasesConfiguration(apiKey));
      Purchases.addCustomerInfoUpdateListener(_customerInfoListener);
      _revenueCatEnabled = true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RevenueCat configure failed: $e\n$st');
      }
    }
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;

    if (_revenueCatEnabled) {
      try {
        final info = await Purchases.getCustomerInfo();
        _applyCustomerInfo(info);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('getCustomerInfo failed: $e\n$st');
        }
        _tier = PremiumTier.free;
        _trialEndMs = null;
      }
    } else {
      _tier = PremiumTier.free;
      _trialEndMs = null;
    }

    _loaded = true;
    notifyListeners();
  }

  void _applyCustomerInfo(CustomerInfo info) {
    final id = RevenueCatConfig.entitlementId;
    final EntitlementInfo? e = info.entitlements.active[id];

    if (e == null || !e.isActive) {
      _tier = PremiumTier.free;
      _trialEndMs = null;
      return;
    }

    final expMs = _expirationToMs(e.expirationDate);

    switch (e.periodType) {
      case PeriodType.trial:
      case PeriodType.intro:
        _tier = PremiumTier.trial;
        _trialEndMs = expMs;
        break;
      case PeriodType.normal:
      case PeriodType.prepaid:
      case PeriodType.unknown:
        _trialEndMs = null;
        final pid = e.productIdentifier.toLowerCase();
        if (pid.contains('year') || pid.contains('annual')) {
          _tier = PremiumTier.yearly;
        } else {
          _tier = PremiumTier.monthly;
        }
        break;
    }
  }

  static int? _expirationToMs(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  Future<Package?> _packageForType(PackageType type) async {
    if (!_revenueCatEnabled) return null;
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

  Future<bool> _purchasePackage(Package? pkg) async {
    if (pkg == null) return false;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(pkg));
      _applyCustomerInfo(result.customerInfo);
      notifyListeners();
      return isEntitled;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      if (kDebugMode) {
        debugPrint('Purchase failed: $e');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Purchase failed: $e');
      }
      return false;
    }
  }

  /// Store-managed introductory offers and trials apply when the user
  /// purchases the yearly product through the store (same as [purchaseYearly]).
  Future<bool> startFreeTrial() => purchaseYearly();

  Future<bool> purchaseMonthly() async {
    await ensureLoaded();
    if (!_revenueCatEnabled) return false;
    final pkg = await _packageForType(PackageType.monthly);
    return _purchasePackage(pkg);
  }

  Future<bool> purchaseYearly() async {
    await ensureLoaded();
    if (!_revenueCatEnabled) return false;
    final pkg = await _packageForType(PackageType.annual);
    return _purchasePackage(pkg);
  }

  Future<bool> restorePurchases() async {
    await ensureLoaded();
    if (!_revenueCatEnabled) return false;
    try {
      final info = await Purchases.restorePurchases();
      _applyCustomerInfo(info);
      notifyListeners();
      return isEntitled;
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

  /// Clears subscription state. In debug + RevenueCat: [Purchases.logOut].
  Future<void> debugResetSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTier);
    await prefs.remove(_kTrialEnd);
    await prefs.remove(_kMockReceipt);

    if (_revenueCatEnabled) {
      try {
        if (await Purchases.isConfigured) {
          final info = await Purchases.logOut();
          _applyCustomerInfo(info);
        } else {
          _tier = PremiumTier.free;
          _trialEndMs = null;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('logOut failed: $e');
        }
        _tier = PremiumTier.free;
        _trialEndMs = null;
      }
    } else {
      _tier = PremiumTier.free;
      _trialEndMs = null;
    }
    notifyListeners();
  }
}
