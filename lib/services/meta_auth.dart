import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MetaAuth {
  static const _tokenKey = 'meta_access_token';
  static const _accountKey = 'meta_ad_account_id';
  static const _pixelKey = 'meta_pixel_id';
  static const _onboardedKey = 'onboarded';

  final _secure = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _secure.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _secure.read(key: _tokenKey);
  }

  Future<void> saveAccountId(String id) async {
    await _secure.write(key: _accountKey, value: id);
  }

  Future<String?> getAccountId() async {
    return _secure.read(key: _accountKey);
  }

  Future<void> savePixelId(String id) async {
    await _secure.write(key: _pixelKey, value: id);
  }

  Future<String?> getPixelId() async {
    return _secure.read(key: _pixelKey);
  }

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  Future<void> setOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
  }

  Future<void> logout() async {
    await _secure.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> hasValidConfig() async {
    final token = await getToken();
    final account = await getAccountId();
    return token != null && token.isNotEmpty && account != null && account.isNotEmpty;
  }
}
