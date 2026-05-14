import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/crypto/aes_gcm_vault.dart';
import '../models/scan_record.dart';
import '../services/isolate_filter_thumb.dart';
import '../services/pdf_export.dart';
import '../services/scan_storage.dart';
import '../services/secure_file_wipe.dart';
import '../services/secure_zip_export.dart';
import '../theme/app_theme.dart';
import '../utils/require_pro.dart';
import '../widgets/qs_snackbar.dart';

class ExportScanScreen extends StatefulWidget {
  const ExportScanScreen({
    super.key,
    required this.pageImages,
    required this.documentTitle,
  });

  final List<Uint8List> pageImages;
  final String documentTitle;

  @override
  State<ExportScanScreen> createState() => _ExportScanScreenState();
}

class _ExportScanScreenState extends State<ExportScanScreen> {
  bool _busy = false;
  bool _success = false;

  String get _safeFileName {
    final raw = widget.documentTitle.replaceAll(RegExp(r'[^\w\-\s]'), '').trim();
    final base = raw.isEmpty ? 'QuickScan' : raw.replaceAll(' ', '_');
    return '$base.pdf';
  }

  int get _approxPdfKb {
    final sum = widget.pageImages.fold<int>(0, (a, b) => a + b.length);
    return (sum * 0.08).round().clamp(32, 1048576);
  }

  Future<File> _persistToEncryptedLibrary(Uint8List rawPdf) async {
    final file = await PdfExport.saveEncryptedVaultFile(
      rawPdf,
      fileName: _safeFileName,
    );
    String? thumbPath;
    try {
      final thumbBytes = await compute(previewResizeIsolate, widget.pageImages.first);
      final base =
          file.path.endsWith('.qsenc') ? file.path.substring(0, file.path.length - 6) : file.path;
      final thumbEnc = await AesGcmVault.encryptBytes(thumbBytes);
      final thumbFile = File('${base}_thumb.qsenc');
      await thumbFile.writeAsBytes(thumbEnc, flush: true);
      thumbPath = thumbFile.path;
    } catch (_) {}

    final record = ScanRecord(
      path: file.path,
      title: widget.documentTitle,
      createdMs: DateTime.now().millisecondsSinceEpoch,
      thumbPath: thumbPath,
    );
    await ScanStorage.prependRecent(record);
    return file;
  }

  Future<String?> _promptZipPassword() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: AppColors.graphite,
            title: const Text('Secure ZIP'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Creates an AES-256 encrypted ZIP containing your PDF. '
                    'Recipients need this password to extract the file (e.g. 7-Zip, Files app).',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.mist),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'ZIP password',
                      hintText: 'At least 4 characters',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _finishSuccess({required String message}) async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = false;
      _success = true;
    });
    QsMessenger.success(context, message);
    await Future<void>.delayed(const Duration(milliseconds: 680));
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Standard export: encrypted copy in library + share plaintext PDF from a temp file.
  Future<void> _exportPdfAndShare({String? via}) async {
    if (!await requirePro(context)) return;
    if (_busy) return;
    setState(() => _busy = true);
    File? shareTemp;
    try {
      final rawPdf = await PdfExport.buildPdfBytes(widget.pageImages);
      await _persistToEncryptedLibrary(rawPdf);
      if (!mounted) return;

      final tmpDir = await getTemporaryDirectory();
      final shareOut = File('${tmpDir.path}/qs_share_${DateTime.now().millisecondsSinceEpoch}.pdf');
      shareTemp = shareOut;
      await shareOut.writeAsBytes(rawPdf, flush: true);

      if (via == 'email') {
        await Share.shareXFiles(
          [XFile(shareOut.path)],
          subject: widget.documentTitle,
          text: 'Scanned with QuickScanner AI (local processing).',
        );
      } else {
        await Share.shareXFiles([XFile(shareOut.path)], subject: widget.documentTitle);
      }

      await _finishSuccess(
        message: via == null ? 'PDF saved to your encrypted library.' : 'Shared successfully.',
      );
    } catch (e) {
      if (mounted) {
        QsMessenger.error(
          context,
          kReleaseMode ? 'Export failed.' : 'Export failed: $e',
        );
      }
    } finally {
      if (shareTemp != null) {
        await secureDeleteFile(shareTemp);
      }
      if (mounted && !_success) {
        setState(() => _busy = false);
      }
    }
  }

  /// Encrypted library copy + share password-protected AES-256 ZIP (plaintext PDF only in memory).
  Future<void> _secureZipExportAndShare({String? via}) async {
    if (!await requirePro(context)) return;
    if (_busy) return;
    final pwd = await _promptZipPassword();
    if (!mounted || pwd == null) return;
    if (pwd.length < 4) {
      QsMessenger.info(context, 'Use at least 4 characters for the ZIP password.');
      return;
    }

    setState(() => _busy = true);
    File? shareTemp;
    try {
      final rawPdf = await PdfExport.buildPdfBytes(widget.pageImages);
      await _persistToEncryptedLibrary(rawPdf);
      if (!mounted) return;

      final zipBytes = SecureZipExport.buildAes256Zip(
        entryFileName: _safeFileName,
        fileBytes: rawPdf,
        password: pwd,
      );

      final tmpDir = await getTemporaryDirectory();
      final zipName = _safeFileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '.zip');
      final shareOut = File('${tmpDir.path}/qs_secure_${DateTime.now().millisecondsSinceEpoch}_$zipName');
      shareTemp = shareOut;
      await shareOut.writeAsBytes(zipBytes, flush: true);

      if (via == 'email') {
        await Share.shareXFiles(
          [XFile(shareOut.path)],
          subject: '${widget.documentTitle} (encrypted ZIP)',
          text: 'Password-protected ZIP from QuickScanner AI. Share the password separately.',
        );
      } else {
        await Share.shareXFiles(
          [XFile(shareOut.path)],
          subject: '${widget.documentTitle} (encrypted ZIP)',
        );
      }

      await _finishSuccess(
        message: via == null
            ? 'Saved to library and prepared encrypted ZIP.'
            : 'Encrypted ZIP shared.',
      );
    } catch (e) {
      if (mounted) {
        QsMessenger.error(
          context,
          kReleaseMode ? 'Secure export failed.' : 'Secure export failed: $e',
        );
      }
    } finally {
      if (shareTemp != null) {
        await secureDeleteFile(shareTemp);
      }
      if (mounted && !_success) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _cloudBackup(String service) async {
    if (!await requirePro(context)) return;
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    QsMessenger.info(
      context,
      'Cloud backup for $service is not enabled. Documents are never uploaded without your explicit consent.',
    );
  }

  void _comingSoon(String name) {
    HapticFeedback.lightImpact();
    QsMessenger.info(context, '$name is coming soon. Use Share for now.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context, false),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppColors.graphite, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: AppColors.ember, size: 20),
          ),
        ),
        title: const Text('Export'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              _PdfPreviewCard(
                previewBytes: widget.pageImages.first,
                title: widget.documentTitle,
                pages: widget.pageImages.length,
                approxKb: _approxPdfKb,
              ),
              const SizedBox(height: 16),
              Text(
                'Export',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.mist),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _exportPdfAndShare(),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Export PDF'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _secureZipExportAndShare(),
                  icon: const Icon(Icons.folder_zip_outlined),
                  label: const Text('Secure ZIP export (password protected)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.snow,
                    side: const BorderSide(color: AppColors.stroke),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Quick actions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.mist),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _QuickExportButton(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      onTap: () => _exportPdfAndShare(via: 'email'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickExportButton(
                      icon: Icons.draw_outlined,
                      label: 'Sign',
                      onTap: () => _comingSoon('Signing'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickExportButton(
                      icon: Icons.print_outlined,
                      label: 'Print',
                      onTap: () => _comingSoon('Print'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Destinations',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.mist),
              ),
              const SizedBox(height: 10),
              _ExportCard(
                child: Column(
                  children: [
                    _ExportRow(
                      icon: Icons.folder_open_outlined,
                      title: 'Files',
                      subtitle: 'On-device storage & iCloud Drive',
                      onTap: () => _exportPdfAndShare(),
                    ),
                    const Divider(height: 1, color: AppColors.stroke),
                    _ExportRow(
                      icon: Icons.cloud_outlined,
                      title: 'Google Drive',
                      onTap: () => _cloudBackup('Google Drive'),
                    ),
                    const Divider(height: 1, color: AppColors.stroke),
                    _ExportRow(
                      icon: Icons.cloud_queue_outlined,
                      title: 'Dropbox',
                      onTap: () => _cloudBackup('Dropbox'),
                    ),
                    const Divider(height: 1, color: AppColors.stroke),
                    _ExportRow(
                      icon: Icons.cloud_circle_outlined,
                      title: 'OneDrive',
                      onTap: () => _cloudBackup('OneDrive'),
                    ),
                    const Divider(height: 1, color: AppColors.stroke),
                    _ExportRow(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      onTap: () => _exportPdfAndShare(via: 'email'),
                    ),
                    const Divider(height: 1, color: AppColors.stroke),
                    _ExportRow(
                      icon: Icons.ios_share_rounded,
                      title: 'Other apps',
                      subtitle: 'AirDrop, Slack, Messages…',
                      onTap: () => _exportPdfAndShare(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: AppColors.ember),
            ),
          if (_success)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 560),
                      curve: Curves.elasticOut,
                      builder: (context, v, child) => Transform.scale(
                        scale: 0.4 + 0.6 * v,
                        child: child,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 108,
                        color: AppColors.ember.withValues(alpha: 0.95),
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PdfPreviewCard extends StatelessWidget {
  const _PdfPreviewCard({
    required this.previewBytes,
    required this.title,
    required this.pages,
    required this.approxKb,
  });

  final Uint8List previewBytes;
  final String title;
  final int pages;
  final int approxKb;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.stroke),
        boxShadow: AppShadows.cardLift(AppColors.ember),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                previewBytes,
                width: 72,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.snow),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Document ($pages page${pages == 1 ? '' : 's'})',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Badge(label: 'PDF'),
                      _Badge(label: '~$approxKb KB'),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                QsMessenger.info(context, 'Format settings are coming soon.');
              },
              icon: const Icon(Icons.settings_outlined, color: AppColors.ember),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.ember.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ember.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.ember,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.stroke),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: child,
      ),
    );
  }
}

class _ExportRow extends StatelessWidget {
  const _ExportRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.ember, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.snow)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickExportButton extends StatelessWidget {
  const _QuickExportButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.graphite,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        splashColor: AppColors.ember.withValues(alpha: 0.14),
        highlightColor: AppColors.ember.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: AppColors.ember),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.snow)),
            ],
          ),
        ),
      ),
    );
  }
}
