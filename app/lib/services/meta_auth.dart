import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MetaAuth {
  static const _tokenKey = 'meta_access_token';
  static const _accountKey = 'meta_ad_account_id';
  static const _pixelKey = 'meta_pixel_id';
  static const _onboardedKey = 'onboarded';

  static const _workerApiKey = 'worker_api_key';
  static const _workerSessionToken = 'worker_session_token';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

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

  Future<bool> hasValidConfig() async {
    final token = await getToken();
    final account = await getAccountId();
    return token != null &&
        token.isNotEmpty &&
        account != null &&
        account.isNotEmpty;
  }

  Future<void> saveApiKey(String key) async {
    await _secure.write(key: _workerApiKey, value: key);
  }

  Future<String?> getApiKey() async {
    return _secure.read(key: _workerApiKey);
  }

  Future<void> deleteApiKey() async {
    await _secure.delete(key: _workerApiKey);
  }

  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<void> saveSessionToken(String token) async {
    await _secure.write(key: _workerSessionToken, value: token);
  }

  Future<String?> getSessionToken() async {
    return _secure.read(key: _workerSessionToken);
  }

  Future<void> deleteSessionToken() async {
    await _secure.delete(key: _workerSessionToken);
  }

  Future<void> logout() async {
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _accountKey);
    await _secure.delete(key: _pixelKey);
    await _secure.delete(key: _workerApiKey);
    await _secure.delete(key: _workerSessionToken);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}