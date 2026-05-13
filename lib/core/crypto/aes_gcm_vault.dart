import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../security/vault_keys.dart';

/// AES-256-GCM for scan files and encrypted preference blobs.
///
/// On-disk format: magic `QSV1` + [nonce || ciphertext || mac] from [SecretBox.concatenation].
final class AesGcmVault {
  AesGcmVault._();

  static final AesGcm _algorithm = AesGcm.with256bits();

  static const List<int> _fileMagic = [0x51, 0x53, 0x56, 0x31]; // "QSV1"

  static bool fileLooksEncrypted(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == _fileMagic[0] &&
      bytes[1] == _fileMagic[1] &&
      bytes[2] == _fileMagic[2] &&
      bytes[3] == _fileMagic[3];

  static Future<Uint8List> encryptBytes(Uint8List plaintext) async {
    final key = await VaultKeys.instance.aes256SecretKey();
    final box = await _algorithm.encrypt(plaintext, secretKey: key);
    final inner = box.concatenation();
    final out = Uint8List(4 + inner.length);
    out.setAll(0, _fileMagic);
    out.setAll(4, inner);
    return out;
  }

  /// Decrypts only vault-wrapped payloads. Used for preferences and OCR cache blobs.
  static Future<Uint8List> decryptBytesIfNeeded(Uint8List input) async {
    if (!fileLooksEncrypted(input)) {
      return input;
    }
    return decryptVaultCiphertext(input);
  }

  /// Decrypts a vault file that **must** be QSV1-wrapped (scans / library). Throws if not.
  static Future<Uint8List> decryptVaultFileStrict(Uint8List input) async {
    if (!fileLooksEncrypted(input)) {
      throw StateError('Invalid or legacy scan file (expected encrypted vault format).');
    }
    return decryptVaultCiphertext(input);
  }

  static Future<Uint8List> decryptVaultCiphertext(Uint8List input) async {
    final inner = input.sublist(4);
    final key = await VaultKeys.instance.aes256SecretKey();
    final box = SecretBox.fromConcatenation(
      inner,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
      copy: true,
    );
    final clear = await _algorithm.decrypt(box, secretKey: key);
    return Uint8List.fromList(clear);
  }
}
