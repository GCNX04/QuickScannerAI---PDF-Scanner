# RevenueCat and store setup (QuickScanner)

Complete these steps in the RevenueCat and store dashboards so in-app purchases work. The app reads **public SDK keys** from `--dart-define` at build time (see below).

## 1. RevenueCat project

1. Create a project at [RevenueCat](https://www.revenuecat.com/).
2. Add **Android** and **iOS** apps with the same bundle / application id as this Flutter app (`ai.quickscanner.pdfscanner` on Android; iOS bundle id from Xcode / `ios/Runner.xcodeproj`).

## 2. Entitlement

1. In RevenueCat, create an **Entitlement** with identifier **`pro`** (or set `REVENUECAT_ENTITLEMENT_ID` to match your id everywhere).
2. Attach your subscription products to this entitlement so active subscriptions unlock `pro`.

## 3. Google Play Console

1. Create **subscription** products (e.g. monthly and yearly) with base plans and offers.
2. Link Play to RevenueCat using RevenueCat’s **Google Play** integration (service account JSON).
3. In RevenueCat, import products and attach them to entitlement **`pro`**.

## 4. App Store Connect

1. Create a **subscription group** and **auto-renewable subscriptions** (monthly + yearly).
2. Add the App Store Connect **In-App Purchase** / subscription key in RevenueCat per their iOS setup guide.

## 5. Offering (required for the paywall)

1. In RevenueCat, open **Offerings** and set a **Current** offering (often named `default`).
2. Add two **packages** to that offering:
   - **Monthly** — package type **Monthly** (maps to `PackageType.monthly` in the SDK).
   - **Annual** — package type **Annual** (maps to `PackageType.annual`).

The app resolves prices from these packages. Custom-only package types are supported as a fallback if the dashboard uses custom identifiers containing `month` / `year` / `annual`.

## 6. Build with API keys (do not commit keys into source)

```bash
flutter run --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx
```

Optional override for entitlement id (default is `pro`):

```bash
--dart-define=REVENUECAT_ENTITLEMENT_ID=pro
```

If keys are omitted on a device, the SDK is not configured and the user stays on the **free** tier until you ship a build with keys.

## 7. Testing

See [TESTING_SUBSCRIPTIONS.md](TESTING_SUBSCRIPTIONS.md) for Play internal testing and App Store sandbox flows.
