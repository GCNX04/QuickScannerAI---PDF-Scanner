import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/crypto/aes_gcm_vault.dart';
import 'scan_storage.dart';

/// Builds PDFs in memory and stores them with AES-256-GCM at rest ([AesGcmVault]).
class PdfExport {
  PdfExport._();

  static Future<Uint8List> buildPdfBytes(List<Uint8List> pageImages) async {
    if (pageImages.isEmpty) {
      throw ArgumentError('At least one page is required to export a PDF.');
    }
    final doc = pw.Document();
    for (final bytes in pageImages) {
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    return Uint8List.fromList(await doc.save());
  }

  /// Writes [plaintextPdf] encrypted to the app sandbox ([ScanStorage.scansDirectory]).
  static Future<File> saveEncryptedVaultFile(
    Uint8List plaintextPdf, {
    String? fileName,
  }) async {
    final enc = await AesGcmVault.encryptBytes(plaintextPdf);
    final dir = await ScanStorage.scansDirectory();
    var base = fileName ?? 'QuickScan_${DateTime.now().millisecondsSinceEpoch}.pdf';
    base = base.replaceAll(RegExp(r'\.(pdf|qsenc)$', caseSensitive: false), '');
    if (base.trim().isEmpty) base = 'QuickScan';
    final outName = '$base.qsenc';
    final file = File('${dir.path}/$outName');
    await file.writeAsBytes(enc, flush: true);
    return file;
  }
}
