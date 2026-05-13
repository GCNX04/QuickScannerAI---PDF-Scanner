import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/crypto/aes_gcm_vault.dart';
import '../models/scan_record.dart';

/// Persists recent scan metadata (encrypted at rest) and resolves the on-disk scans folder.
class ScanStorage {
  ScanStorage._();

  static const _prefsKeyEnc = 'quickscanner_recent_scans_v2_enc';
  static const _prefsKeyLegacy = 'quickscanner_recent_scans_v1';
  static const _maxRecents = 30;

  static Future<Directory> scansDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/scans');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// One-time migration: legacy plaintext `.pdf` / `_thumb.jpg` → vault `.qsenc` files and prefs paths.
  static Future<void> migrateLegacyPlaintextArtifacts() async {
    final dir = await scansDirectory();
    if (!await dir.exists()) return;

    final prefs = await SharedPreferences.getInstance();

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      final lower = path.toLowerCase();
      if (lower.endsWith('.pdf')) {
        try {
          final bytes = await entity.readAsBytes();
          if (bytes.length < 5) continue;
          if (bytes[0] != 0x25 || bytes[1] != 0x50 || bytes[2] != 0x44 || bytes[3] != 0x46) {
            continue;
          }
          final base = path.substring(0, path.length - 4);
          final newPath = '$base.qsenc';
          final enc = await AesGcmVault.encryptBytes(bytes);
          await File(newPath).writeAsBytes(enc, flush: true);
          await entity.delete();

          final thumbJpg = File('${base}_thumb.jpg');
          if (await thumbJpg.exists()) {
            final tBytes = await thumbJpg.readAsBytes();
            final tEnc = await AesGcmVault.encryptBytes(tBytes);
            await File('${base}_thumb.qsenc').writeAsBytes(tEnc, flush: true);
            await thumbJpg.delete();
          }
        } catch (_) {}
      } else if (lower.endsWith('_thumb.jpg')) {
        try {
          final base = path.substring(0, path.length - '_thumb.jpg'.length);
          final vaultPdf = File('$base.qsenc');
          if (!await vaultPdf.exists()) continue;
          final tBytes = await entity.readAsBytes();
          final tEnc = await AesGcmVault.encryptBytes(tBytes);
          await File('${base}_thumb.qsenc').writeAsBytes(tEnc, flush: true);
          await entity.delete();
        } catch (_) {}
      }
    }

    final json = await _readRecentsJson(prefs);
    if (json.isEmpty) return;
    try {
      final list = jsonDecode(json) as List<dynamic>;
      var changed = false;
      final next = <ScanRecord>[];
      for (final item in list) {
        final r = ScanRecord.fromJson(item);
        if (r == null) continue;
        var path = r.path;
        var thumb = r.thumbPath;
        if (path.toLowerCase().endsWith('.pdf')) {
          final alt = '${path.substring(0, path.length - 4)}.qsenc';
          if (await File(alt).exists()) {
            path = alt;
            changed = true;
          }
        }
        if (thumb != null && thumb.toLowerCase().endsWith('.jpg')) {
          final b = thumb.substring(0, thumb.length - '_thumb.jpg'.length);
          final altT = '${b}_thumb.qsenc';
          if (await File(altT).exists()) {
            thumb = altT;
            changed = true;
          }
        }
        if (await File(path).exists()) {
          next.add(ScanRecord(path: path, title: r.title, createdMs: r.createdMs, thumbPath: thumb));
        }
      }
      if (changed) {
        await _writeRecentsJson(prefs, jsonEncode(next.map((e) => e.toJson()).toList()));
      }
    } catch (_) {}
  }

  static Future<String> _readRecentsJson(SharedPreferences prefs) async {
    final encB64 = prefs.getString(_prefsKeyEnc);
    if (encB64 != null && encB64.isNotEmpty) {
      final raw = Uint8List.fromList(base64Decode(encB64));
      final clear = await AesGcmVault.decryptBytesIfNeeded(raw);
      return utf8.decode(clear);
    }
    final legacy = prefs.getString(_prefsKeyLegacy);
    if (legacy != null && legacy.isNotEmpty) {
      await _writeRecentsJson(prefs, legacy);
      await prefs.remove(_prefsKeyLegacy);
      return legacy;
    }
    return '[]';
  }

  static Future<void> _writeRecentsJson(SharedPreferences prefs, String json) async {
    final enc = await AesGcmVault.encryptBytes(Uint8List.fromList(utf8.encode(json)));
    await prefs.setString(_prefsKeyEnc, base64Encode(enc));
  }

  static Future<List<ScanRecord>> loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final json = await _readRecentsJson(prefs);
    if (json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      final out = <ScanRecord>[];
      for (final item in list) {
        final r = ScanRecord.fromJson(item);
        if (r != null && await File(r.path).exists()) {
          out.add(r);
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> prependRecent(ScanRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final json = await _readRecentsJson(prefs);
    List<dynamic> existing = [];
    try {
      existing = (jsonDecode(json) as List<dynamic>?) ?? [];
    } catch (_) {
      existing = [];
    }
    final parsed = <ScanRecord>[];
    for (final item in existing) {
      final r = ScanRecord.fromJson(item);
      if (r != null) parsed.add(r);
    }
    final next = <ScanRecord>[record, ...parsed.where((e) => e.path != record.path)]
        .take(_maxRecents)
        .toList();
    await _writeRecentsJson(
      prefs,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> removeIfMissing(String path) async {
    if (await File(path).exists()) return;
    final prefs = await SharedPreferences.getInstance();
    final json = await _readRecentsJson(prefs);
    try {
      final list = (jsonDecode(json) as List<dynamic>?) ?? [];
      final next = <ScanRecord>[];
      for (final item in list) {
        final r = ScanRecord.fromJson(item);
        if (r != null && r.path != path) next.add(r);
      }
      await _writeRecentsJson(
        prefs,
        jsonEncode(next.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }
}
