# Testing subscriptions (QuickScanner)

## Prerequisites

- A build with valid `--dart-define` RevenueCat keys for the target platform.
- RevenueCat **Current** offering with monthly + annual packages, linked to entitlement **`pro`** (or your `REVENUECAT_ENTITLEMENT_ID`).

## Google Play (internal / license testing)

1. Upload an **internal testing** or **closed testing** track AAB.
2. Add **license testers** in Play Console.
3. Install the app from the Play testing link (not sideload-only debug if Play Billing requires store install for some flows).
4. Open **QuickScanner Pro** paywall, purchase monthly or yearly, confirm Pro features unlock.
5. Use **Restore purchases** after clearing app data or on a second device with the same Play account.

## App Store (sandbox)

1. Create a **Sandbox Apple ID** in App Store Connect.
2. On device: sign out of production Media & Purchases if needed; sign in with sandbox when prompted during purchase.
3. Run through subscribe, restore, and cancellation / expiry where applicable.

## Android emulator

Use an image with **Google Play** services. Billing may still require proper test accounts and sometimes a build from an internal track.

## Debug menu

In **debug** builds only, **Reset subscription** calls `Purchases.logOut()` when RevenueCat is configured, then refreshes entitlements. Use for QA; never expose a customer-facing reset in release.
