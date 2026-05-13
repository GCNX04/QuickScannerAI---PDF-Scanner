import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Password-protected ZIP using WinZip-compatible **AES-256** (via the `archive` package).
///
/// Opens in standard tools (7-Zip, Windows Explorer, macOS Archive Utility, etc.) with the same password.
final class SecureZipExport {
  SecureZipExport._();

  static const int _minPasswordLength = 4;

  /// [entryFileName] should end in `.pdf` for clarity inside the archive.
  static Uint8List buildAes256Zip({
    required String entryFileName,
    required Uint8List fileBytes,
    required String password,
  }) {
    final pwd = password.trim();
    if (pwd.length < _minPasswordLength) {
      throw ArgumentError('ZIP password must be at least $_minPasswordLength characters.');
    }
    final name = entryFileName.toLowerCase().endsWith('.pdf')
        ? entryFileName
        : '$entryFileName.pdf';
    final archive = Archive()..addFile(ArchiveFile(name, fileBytes.length, fileBytes));
    return Uint8List.fromList(ZipEncoder(password: pwd).encode(archive));
  }
}
