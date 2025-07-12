// lib/secure_storage_service.dart
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  /* ───────── singleton ───────── */
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /* ───────── public API ───────── */
  Future<void> writeData(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (e) {
      // iOS duplicate item → errSecDuplicateItem == -25299
      if (_isDuplicateItemError(e)) {
        await _storage.delete(key: key);
        await _storage.write(key: key, value: value);
      } else {
        rethrow;
      }
    }
  }

  Future<String?> readData(String key) async =>
      _storage.read(key: key);

  Future<void> deleteData(String key) async =>
      _storage.delete(key: key);

  Future<void> deleteAllData() async =>
      _storage.deleteAll();

  /* ───────── helper ───────── */
  bool _isDuplicateItemError(PlatformException e) {
    // -25299 is Apple's errSecDuplicateItem
    return e.details == -25299 ||
        (e.message != null &&
            e.message!.toLowerCase().contains('already exists'));
  }
}