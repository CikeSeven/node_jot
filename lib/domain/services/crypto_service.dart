import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 加密服务。
///
/// 协议约定：
/// - 密钥交换：X25519
/// - 会话密钥派生：HKDF-SHA256
/// - 消息加密：AES-256-GCM
class CryptoService {
  final X25519 _x25519 = X25519();
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// 生成 X25519 密钥对并返回 Base64 编码结果。
  Future<Map<String, String>> generateX25519KeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final privateKey = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    return {
      'privateKey': base64Encode(privateKey),
      'publicKey': base64Encode(publicKey.bytes),
    };
  }

  /// 基于双方密钥和配对码派生共享密钥。
  Future<String> deriveSharedKey({
    required String myPrivateKeyBase64,
    required String remotePublicKeyBase64,
    required String pairingCode,
  }) async {
    final privateBytes = base64Decode(myPrivateKeyBase64);
    final remoteBytes = base64Decode(remotePublicKeyBase64);

    final keyPair = await _x25519.newKeyPairFromSeed(privateBytes);
    final remote = SimplePublicKey(remoteBytes, type: KeyPairType.x25519);

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remote,
    );

    final salt = utf8.encode('nodejot:$pairingCode');
    final info = utf8.encode('nodejot-sync-channel');
    final derived = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: salt,
      info: info,
    );
    final bytes = await derived.extractBytes();
    return base64Encode(bytes);
  }

  /// 使用共享密钥加密业务载荷，产出安全信封结构。
  Future<Map<String, dynamic>> encryptEnvelope({
    required Map<String, dynamic> payload,
    required String keyBase64,
    required String senderDeviceId,
  }) async {
    final keyBytes = base64Decode(keyBase64);
    final secretKey = SecretKey(keyBytes);
    final nonce = _randomBytes(12);
    final plain = utf8.encode(jsonEncode(payload));

    final box = await _aesGcm.encrypt(
      plain,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'type': 'secure_message',
      'deviceId': senderDeviceId,
      'nonce': base64Encode(nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  /// 解密安全信封并还原业务载荷。
  Future<Map<String, dynamic>> decryptEnvelope({
    required Map<String, dynamic> envelope,
    required String keyBase64,
  }) async {
    final keyBytes = base64Decode(keyBase64);
    final secretKey = SecretKey(keyBytes);
    final nonce = base64Decode(envelope['nonce'] as String);
    final cipherText = base64Decode(envelope['cipherText'] as String);
    final macBytes = base64Decode(envelope['mac'] as String);

    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final plain = await _aesGcm.decrypt(box, secretKey: secretKey);
    final decoded = jsonDecode(utf8.decode(plain)) as Map;
    return decoded.cast<String, dynamic>();
  }

  /// 生成加密所需随机字节。
  Uint8List _randomBytes(int size) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(size, (_) => random.nextInt(256)),
    );
  }
}
