import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  static const String _cloudSyncKey = 'cloudSync';
  static const String _darkModeKey = 'darkMode';
  static const String _mintUrlKey = 'mintUrl';
  static const String _seedKey = 'seed';

  final _preferences = SharedPreferencesAsync();
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock, synchronizable: true),
  );

  Future<void> clear() async {
    await _storage.deleteAll();
  }

  Future<String?> getMintUrl() async {
    return await _storage.read(key: _mintUrlKey);
  }

  Future<String?> getSeed() async {
    return await _storage.read(key: _seedKey);
  }

  Future<bool> isCloudSyncEnabled() async {
    return await _preferences.getBool(_cloudSyncKey) ?? true;
  }

  Future<bool> isDarkMode() async {
    return await _preferences.getBool(_darkModeKey) ?? false;
  }

  Future<void> setCloudSyncEnabled(bool isEnabled) async {
    await _preferences.setBool(_cloudSyncKey, isEnabled);
  }

  Future<void> setDarkMode(bool isDarkMode) async {
    await _preferences.setBool(_darkModeKey, isDarkMode);
  }

  Future<void> setMintUrl(String mint) async {
    await _storage.write(key: _mintUrlKey, value: mint);
  }

  Future<void> setSeed(String seed) async {
    await _storage.write(key: _seedKey, value: seed);
  }
}
