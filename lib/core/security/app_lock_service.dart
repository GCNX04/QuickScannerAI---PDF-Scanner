import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric / device credential gate when app lock is enabled.
final class AppLockService extends ChangeNotifier {
  AppLockService._();

  static final AppLockService instance = AppLockService._();

  static const _prefsKey = 'qs_app_lock_biometric_v1';

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _biometricLockEnabled = false;
  bool _unlocked = true;

  bool get biometricLockEnabled => _biometricLockEnabled;

  /// When true, a full-screen lock UI should block the app shell.
  bool get shouldShowLock => _biometricLockEnabled && !_unlocked;

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _biometricLockEnabled = prefs.getBool(_prefsKey) ?? false;
    _unlocked = !_biometricLockEnabled;
    notifyListeners();
  }

  Future<void> setBiometricLockEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      final ok = await authenticate(
        reason: 'Confirm Face ID / fingerprint to enable app lock.',
      );
      if (!ok) return;
    }
    _biometricLockEnabled = value;
    await prefs.setBool(_prefsKey, value);
    _unlocked = true;
    notifyListeners();
  }

  void lockForBackground() {
    if (!_biometricLockEnabled) return;
    _unlocked = false;
    notifyListeners();
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      final can = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!can) return false;
      return _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> tryUnlock() async {
    final ok = await authenticate(
      reason: 'Authenticate to open QuickScanner AI.',
    );
    if (ok) {
      _unlocked = true;
      notifyListeners();
    }
    return ok;
  }
}
