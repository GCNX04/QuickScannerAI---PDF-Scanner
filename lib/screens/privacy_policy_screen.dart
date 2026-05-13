import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// In-app privacy policy for store listings and user trust.
///
/// Host the same text on a public URL for Google Play / App Store privacy links.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.mist,
          height: 1.45,
        );
    final h2 = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.snow,
          fontWeight: FontWeight.w800,
        );
    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      appBar: AppBar(
        title: const Text('Privacy & security'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('QuickScanner AI — PDF Scanner', style: h2),
          const SizedBox(height: 8),
          Text(
            'Effective date: May 13, 2026. This policy describes how the QuickScanner AI mobile application '
            '(“the App”) treats information when you scan documents, run OCR, and export PDFs.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text('Local-first processing', style: h2),
          const SizedBox(height: 8),
          Text(
            'Scanning, optical character recognition (OCR), PDF creation, filters, and compression run on your device. '
            'We do not upload your scanned pages or PDFs to our servers by default. Optional cloud features, if offered in the future, '
            'will be clearly labeled and require your explicit consent before any document leaves your device.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text('What we do not collect', style: h2),
          const SizedBox(height: 8),
          Text(
            'The App is built without third-party advertising SDKs and without behavioral analytics tied to your documents. '
            'We do not sell your scans or OCR text. We do not request contacts, SMS, microphone (for scanning), precise location, '
            'or phone state for core functionality.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text('On-device storage & encryption', style: h2),
          const SizedBox(height: 8),
          Text(
            'Saved scans are stored only in the operating system’s private app sandbox. PDFs and thumbnails are encrypted on disk '
            'using AES-256-GCM. Encryption keys are held in the iOS Keychain and Android Keystore-backed secure storage via '
            'flutter_secure_storage — keys are not hardcoded in the app binary.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text('Biometric app lock', style: h2),
          const SizedBox(height: 8),
          Text(
            'If you enable app lock, Face ID, Touch ID, fingerprint, or your device PIN (depending on platform and settings) '
            'can be required when you return from the background. Biometric data never leaves your device; the App only receives '
            'success or failure from the system authenticator.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text('Exports & sharing', style: h2),
          const SizedBox(height: 8),
          Text(
            'Standard export shares a normal PDF via the system share sheet, email, or other apps you choose. '
            'OCR text cache on disk is encrypted with the same vault key (not plaintext). '
            'Secure ZIP export wraps the PDF in a password-protected ZIP file using AES-256 (WinZip-compatible format via the open-source archive package). '
            'Temporary files used for sharing are overwritten and deleted where possible. '
            'Receiving apps or services apply their own privacy policies to anything you send them.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text('Secure ZIP export', style: h2),
          const SizedBox(height: 8),
          Text(
            'If you choose Secure ZIP export, you set a password that encrypts the archive. You are responsible for sharing the password '
            'with recipients through a separate channel. We cannot recover a lost ZIP password.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text('Network & security', style: h2),
          const SizedBox(height: 8),
          Text(
            'The App is designed for offline use. If a future update performs network calls, those calls will use HTTPS only; '
            'Android is configured to disallow cleartext traffic. We do not intentionally log document contents or OCR text on any server.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text('Children’s privacy', style: h2),
          const SizedBox(height: 8),
          Text(
            'The App is not directed at children under 13 (or the minimum age in your jurisdiction). Do not use the App to process '
            'children’s personal information unless you have appropriate authority and consent.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text('Data retention', style: h2),
          const SizedBox(height: 8),
          Text(
            'Your scans remain on your device until you delete them from the App or uninstall the App. Uninstalling may erase '
            'sandboxed data according to platform rules. OCR cache files may be removed when you clear app data or reinstall.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text('Your rights (GDPR-style)', style: h2),
          const SizedBox(height: 8),
          Text(
            'Because processing is local, you can access, copy, export, or delete your documents entirely from the device. '
            'If we ever process personal data on our servers, we will provide contact details and honor applicable access, '
            'rectification, portability, and erasure requests.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text('Changes', style: h2),
          const SizedBox(height: 8),
          Text(
            'We may update this policy when features change. Continued use of the App after an update constitutes acceptance of '
            'the revised policy where permitted by law.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text('Contact', style: h2),
          const SizedBox(height: 8),
          Text(
            'For privacy questions, provide a support email or web form in your store listing and replace this sentence with that contact.',
            style: body,
          ),
        ],
      ),
    );
  }
}
