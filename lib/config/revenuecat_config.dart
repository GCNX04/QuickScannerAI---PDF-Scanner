/// Build-time RevenueCat configuration (`--dart-define`, see docs/REVENUECAT_SETUP.md).
///
/// This app ships **Android only** for billing: only [androidApiKey] is used at runtime.
/// [iosApiKey] is reserved for a future iOS build and is ignored by [PremiumService].
abstract final class RevenueCatConfig {
  /// Must match the entitlement identifier in the RevenueCat dashboard.
  static const String entitlementId = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ID',
    defaultValue: 'pro',
  );

  /// Required on Android builds that enable subscriptions (`--dart-define=...`).
  static const String androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: '',
  );

  /// Unused for the current Android-only product; kept for optional future iOS.
  static const String iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: '',
  );
}
