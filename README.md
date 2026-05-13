# QuickScanner AI — PDF Scanner

Privacy-first Flutter document scanner: capture pages, run **on-device OCR** with Google ML Kit, and export **PDF** or a **password-protected AES ZIP** of your scans. Scans and OCR cache are protected with local vault encryption (AES-256-GCM) and optional **biometric app lock**.

Repository: [https://github.com/GCNX04/QuickScannerAI---PDF-Scanner](https://github.com/GCNX04/QuickScannerAI---PDF-Scanner)

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) SDK **3.5+** (Dart **3.5+**)
- For Android: Android SDK as required by your Flutter channel (min SDK **24**)
- For iOS: Xcode and CocoaPods when building for Apple platforms

## Run the app

```bash
flutter pub get
flutter run
```

Pick a device or emulator when prompted.

## Android release builds (Play Store)

Release APK/AAB builds expect release signing configuration:

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Fill in keystore path, store password, key alias, and key password.
3. Keep `key.properties` and keystore files **out of version control** (already ignored in `.gitignore`).

Then:

```bash
flutter build appbundle
# or
flutter build apk --release
```

ProGuard / R8 rules for ML Kit optional script models live in `android/app/proguard-rules.pro`.

## Project layout (high level)

| Area | Role |
|------|------|
| `lib/main.dart` | App entry, vault initialization, legacy migration hooks |
| `lib/core/crypto/` | AES-GCM vault helpers |
| `lib/core/security/` | Secure storage keys, app lock lifecycle |
| `lib/services/` | Scan storage, PDF export, secure ZIP, OCR, ML Kit |
| `lib/screens/` | Home, scanner, editor, export, privacy policy |
| `android/` | App ID `ai.quickscanner.pdfscanner`, network security, signing |

## License

Specify your license here if you publish the repo publicly.
