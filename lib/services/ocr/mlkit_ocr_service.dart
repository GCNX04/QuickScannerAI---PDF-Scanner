import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/crypto/aes_gcm_vault.dart';
import '../../core/logging/qs_log.dart';
import 'ocr_platform.dart';

/// Disk-backed OCR cache (AES-256-GCM under [AesGcmVault], extension `.qsc`).
abstract final class OcrDiskCache {
  static const _folder = 'qs_ocr_cache';

  static Future<Directory> _dir() async {
    final root = await getApplicationSupportDirectory();
    final d = Directory('${root.path}/$_folder');
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  static String keyForBytes(Uint8List bytes) => sha256.convert(bytes).toString();

  static Future<String?> read(String cacheKey) async {
    try {
      final d = await _dir();
      final encFile = File('${d.path}/$cacheKey.qsc');
      if (await encFile.exists()) {
        final raw = await encFile.readAsBytes();
        final clear = await AesGcmVault.decryptBytesIfNeeded(raw);
        return utf8.decode(clear);
      }
      final leg = File('${d.path}/$cacheKey.txt');
      if (await leg.exists()) {
        final s = await leg.readAsString();
        await leg.delete();
        if (s.isNotEmpty) {
          await write(cacheKey, s);
        }
        return s.isEmpty ? null : s;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> write(String cacheKey, String text) async {
    try {
      final d = await _dir();
      final enc = await AesGcmVault.encryptBytes(Uint8List.fromList(utf8.encode(text)));
      await File('${d.path}/$cacheKey.qsc').writeAsBytes(enc, flush: true);
    } catch (_) {}
  }
}

/// On-device text recognition (Google ML Kit). Must be disposed when the editor closes.
class MlKitOcrService {
  TextRecognizer? _recognizer;

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }

  /// Runs ML Kit on [jpegBytes]. Uses disk cache unless [bypassCache] is true.
  Future<String> recognizeJpegBytes(Uint8List jpegBytes, {bool bypassCache = false}) async {
    if (jpegBytes.isEmpty) return '';

    final cacheKey = OcrDiskCache.keyForBytes(jpegBytes);
    if (!bypassCache) {
      final hit = await OcrDiskCache.read(cacheKey);
      if (hit != null) return hit;
    }

    if (!isMlKitTextRecognitionPlatformSupported) {
      const msg =
          'On-device OCR runs on Android and iOS. Build for a phone or tablet to extract text with ML Kit.';
      return msg;
    }

    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

    File? tmp;
    try {
      final dir = await getTemporaryDirectory();
      tmp = File('${dir.path}/qs_ocr_$cacheKey.jpg');
      await tmp.writeAsBytes(jpegBytes, flush: true);
      final input = InputImage.fromFilePath(tmp.path);
      final result = await _recognizer!.processImage(input);
      final text = result.text.trim();
      if (text.isNotEmpty) {
        await OcrDiskCache.write(cacheKey, text);
      }
      return text;
    } catch (e, st) {
      qsLog('OCR failed', error: e, stackTrace: st);
      if (kReleaseMode) {
        return 'OCR failed on this image. Try a sharper scan or different lighting.';
      }
      return 'OCR failed on this image. Try a sharper scan or different lighting.\n($e)';
    } finally {
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }
}
