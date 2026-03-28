import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionUtils {
  static const _storage = FlutterSecureStorage();
  static const _keyId = 'privavoice_aes_key';
  static const _ivId = 'privavoice_aes_iv';
  
  static Key? _key;
  static IV? _iv;
  
  static Future<void> initialize() async {
    final storedKey = await _storage.read(key: _keyId);
    final storedIv = await _storage.read(key: _ivId);
    
    if (storedKey != null && storedIv != null) {
      _key = Key(base64Decode(storedKey));
      _iv = IV(base64Decode(storedIv));
    } else {
      _key = Key.fromSecureRandom(32); // 256-bit
      _iv = IV.fromSecureRandom(12); // 96-bit for GCM
      
      await _storage.write(key: _keyId, value: base64Encode(_key!.bytes));
      await _storage.write(key: _ivId, value: base64Encode(_iv!.bytes));
    }
  }
  
  static Future<String> encrypt(String plainText) async {
    if (_key == null || _iv == null) {
      await initialize();
    }
    
    final encrypter = Encrypter(AES(_key!, mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }
  
  static Future<String> decrypt(String encryptedText) async {
    if (_key == null || _iv == null) {
      await initialize();
    }
    
    final encrypter = Encrypter(AES(_key!, mode: AESMode.gcm));
    final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
    return decrypted;
  }
  
  static Future<Uint8List> encryptBytes(Uint8List data) async {
    if (_key == null || _iv == null) {
      await initialize();
    }
    
    final encrypter = Encrypter(AES(_key!, mode: AESMode.gcm));
    final encrypted = encrypter.encryptBytes(data, iv: _iv);
    return encrypted.bytes;
  }
  
  static Future<Uint8List> decryptBytes(Uint8List encryptedData) async {
    if (_key == null || _iv == null) {
      await initialize();
    }
    
    final encrypter = Encrypter(AES(_key!, mode: AESMode.gcm));
    final decrypted = encrypter.decryptBytes(Encrypted(encryptedData), iv: _iv);
    return Uint8List.fromList(decrypted);
  }
}
