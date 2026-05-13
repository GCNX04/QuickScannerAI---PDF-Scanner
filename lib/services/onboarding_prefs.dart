import 'package:shared_preferences/shared_preferences.dart';

/// First-launch onboarding gate.
class OnboardingPrefs {
  OnboardingPrefs._();

  static const prefsKey = 'quickscanner_onboarding_done_v1';

  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? false;
  }

  static Future<void> setCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, true);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }
}
