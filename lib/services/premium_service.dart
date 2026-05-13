import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stored subscription tier (mock billing — replace with StoreKit / Play Billing later).
enum PremiumTier {
  free,
  trial,
  monthly,
  yearly,
}

/// Global mock subscription + entitlement checks.
class PremiumService extends ChangeNotifier {
  PremiumService._();

  static final PremiumService instance = PremiumService._();

  static const _kTier = 'qs_premium_tier_v1';
  static const _kTrialEnd = 'qs_premium_trial_end_ms_v1';
  static const _kMockReceipt = 'qs_mock_purchase_receipt_v1';

  static const int freePageLimit = 8;
  static const int trialDays = 7;

  PremiumTier _tier = PremiumTier.free;
  int? _trialEndMs;
  bool _loaded = false;

  PremiumTier get tier => _tier;
  bool get isLoaded => _loaded;

  /// Active paid or non-expired trial.
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

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _tier = _parseTier(prefs.getString(_kTier));
    _trialEndMs = prefs.getInt(_kTrialEnd);
    _normalizeExpiredTrial();
    _loaded = true;
    notifyListeners();
  }

  PremiumTier _parseTier(String? raw) {
    switch (raw) {
      case 'trial':
        return PremiumTier.trial;
      case 'monthly':
        return PremiumTier.monthly;
      case 'yearly':
        return PremiumTier.yearly;
      default:
        return PremiumTier.free;
    }
  }

  void _normalizeExpiredTrial() {
    if (_tier != PremiumTier.trial) return;
    final end = _trialEndMs;
    if (end == null || DateTime.now().millisecondsSinceEpoch >= end) {
      _tier = PremiumTier.free;
      _trialEndMs = null;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTier, _tier.name);
    if (_trialEndMs != null) {
      await prefs.setInt(_kTrialEnd, _trialEndMs!);
    } else {
      await prefs.remove(_kTrialEnd);
    }
    notifyListeners();
  }

  /// Mock: start 7-day trial (does not stack if already entitled).
  Future<bool> startFreeTrial() async {
    await ensureLoaded();
    if (isEntitled) return true;
    await Future<void>.delayed(const Duration(milliseconds: 420));
    _tier = PremiumTier.trial;
    _trialEndMs = DateTime.now().add(const Duration(days: trialDays)).millisecondsSinceEpoch;
    await _save();
    return true;
  }

  Future<bool> purchaseMonthly() async {
    await ensureLoaded();
    await Future<void>.delayed(const Duration(milliseconds: 520));
    _tier = PremiumTier.monthly;
    _trialEndMs = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMockReceipt, 'monthly');
    await _save();
    return true;
  }

  Future<bool> purchaseYearly() async {
    await ensureLoaded();
    await Future<void>.delayed(const Duration(milliseconds: 520));
    _tier = PremiumTier.yearly;
    _trialEndMs = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMockReceipt, 'yearly');
    await _save();
    return true;
  }

  /// Mock restore: reads last "purchased" plan from prefs.
  Future<bool> restorePurchases() async {
    await ensureLoaded();
    await Future<void>.delayed(const Duration(milliseconds: 680));
    final prefs = await SharedPreferences.getInstance();
    final receipt = prefs.getString(_kMockReceipt);
    if (receipt == 'yearly') {
      _tier = PremiumTier.yearly;
      _trialEndMs = null;
      await _save();
      return true;
    }
    if (receipt == 'monthly') {
      _tier = PremiumTier.monthly;
      _trialEndMs = null;
      await _save();
      return true;
    }
    return false;
  }

  /// Clears mock subscription state (exposed from debug settings only).
  Future<void> debugResetSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTier);
    await prefs.remove(_kTrialEnd);
    await prefs.remove(_kMockReceipt);
    _tier = PremiumTier.free;
    _trialEndMs = null;
    notifyListeners();
  }
}
