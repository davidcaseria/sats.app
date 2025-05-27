import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStorage {
  static const String _mintUrlKey = 'mintUrl';
  static const String _seedKey = 'seed';
  final _storage = const FlutterSecureStorage(iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock, synchronizable: true));

  Future<void> clear() async {
    await _storage.deleteAll();
  }

  Future<String?> getMintUrl() async {
    return await _storage.read(key: _mintUrlKey);
  }

  Future<String?> getSeed() async {
    return await _storage.read(key: _seedKey);
  }

  Future<void> setMintUrl(String mint) async {
    await _storage.write(key: _mintUrlKey, value: mint);
  }

  Future<void> setSeed(String seed) async {
    await _storage.write(key: _seedKey, value: seed);
  }
}
