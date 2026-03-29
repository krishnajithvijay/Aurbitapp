import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static EncryptionService? _instance;
  static EncryptionService get instance => _instance ??= EncryptionService._();
  EncryptionService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _privateKeyStorageKey = 'aurbit_e2e_private_key';

  final _x25519 = X25519();
  final _aesGcm = AesGcm.with256bits();

  /// Generate a new X25519 keypair for this user
  Future<SimpleKeyPair> generateKeyPair() async {
    return _x25519.newKeyPair();
  }

  /// Export public key to base64 string for storage in Supabase
  Future<String> exportPublicKey(SimplePublicKey publicKey) async {
    final bytes = await publicKey.extractBytes();
    return base64Encode(bytes);
  }

  /// Import public key from base64 string
  Future<SimplePublicKey> importPublicKey(String base64Key) async {
    final bytes = base64Decode(base64Key);
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  /// Store private key securely on device
  Future<void> storePrivateKey(SimpleKeyPairData? privateKey) async {
    if (privateKey == null) return;
    final bytes = await privateKey.extractBytes();
    await _storage.write(key: _privateKeyStorageKey, value: base64Encode(bytes));
  }

  Future<void> storePrivateKeyFromKeyPair(SimpleKeyPair keyPair) async {
    final privKey = await keyPair.extract();
    await storePrivateKey(privKey);
  }

  /// Load private key from secure storage
  Future<SimpleKeyPair?> loadPrivateKey() async {
    final stored = await _storage.read(key: _privateKeyStorageKey);
    if (stored == null) return null;
    final bytes = base64Decode(stored);
    return SimpleKeyPairData(
      bytes,
      publicKey: SimplePublicKey([], type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
  }

  /// Derive shared secret from own private key + recipient's public key
  Future<SecretKey> deriveSharedSecret(
    SimpleKeyPair ownKeyPair,
    SimplePublicKey recipientPublicKey,
  ) async {
    return _x25519.sharedSecretKey(
      keyPair: ownKeyPair,
      remotePublicKey: recipientPublicKey,
    );
  }

  /// Encrypt a message for a recipient
  /// Returns base64-encoded ciphertext and iv as a map
  Future<Map<String, String>> encryptMessage({
    required String plaintext,
    required String recipientPublicKeyBase64,
    required SimpleKeyPair senderKeyPair,
  }) async {
    final recipientPubKey = await importPublicKey(recipientPublicKeyBase64);
    final sharedSecret = await deriveSharedSecret(senderKeyPair, recipientPubKey);

    final secretBox = await _aesGcm.encryptString(
      plaintext,
      secretKey: sharedSecret,
    );

    return {
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  /// Decrypt a message from a sender
  Future<String?> decryptMessage({
    required Map<String, String> encryptedData,
    required String senderPublicKeyBase64,
    required SimpleKeyPair recipientKeyPair,
  }) async {
    try {
      final senderPubKey = await importPublicKey(senderPublicKeyBase64);
      final sharedSecret = await deriveSharedSecret(recipientKeyPair, senderPubKey);

      final cipherText = base64Decode(encryptedData['ciphertext']!);
      final nonce = base64Decode(encryptedData['nonce']!);
      final mac = Mac(base64Decode(encryptedData['mac']!));

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      final plaintext = await _aesGcm.decryptString(secretBox, secretKey: sharedSecret);
      return plaintext;
    } catch (e) {
      return null;
    }
  }

  /// Simple hash for checking message integrity
  String hashMessage(String content) {
    final bytes = utf8.encode(content);
    int hash = 0;
    for (final byte in bytes) {
      hash = (hash * 31 + byte) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  Future<bool> hasStoredKeyPair() async {
    final stored = await _storage.read(key: _privateKeyStorageKey);
    return stored != null;
  }

  Future<void> clearKeys() async {
    await _storage.delete(key: _privateKeyStorageKey);
  }
}
