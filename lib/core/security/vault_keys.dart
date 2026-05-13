import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the app data encryption key in Keychain (iOS) / Keystore-backed storage (Android).
///
/// Never log or persist this key outside [FlutterSecureStorage].
final class VaultKeys {
  VaultKeys._();

  static final VaultKeys instance = VaultKeys._();

  static const _storageKey = 'qs_aes256_data_key_v1';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  SecretKey? _memory;

  Future<void> ensureInitialized() async {
    await _loadOrCreateAesKey();
  }

  Future<SecretKey> aes256SecretKey() async => _loadOrCreateAesKey();

  Future<SecretKey> _loadOrCreateAesKey() async {
    if (_memory != null) return _memory!;
    final existing = await _storage.read(key: _storageKey);
    if (existing != null && existing.isNotEmpty) {
      final bytes = base64Decode(existing);
      if (bytes.length == 32) {
        _memory = SecretKey(bytes);
        return _memory!;
      }
    }
    final key = await AesGcm.with256bits().newSecretKey();
    final raw = await key.extractBytes();
    await _storage.write(key: _storageKey, value: base64Encode(raw));
    _memory = SecretKey(raw);
    return _memory!;
  }
}
