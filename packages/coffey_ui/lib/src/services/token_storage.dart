import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Encrypted OS keychain storage on mobile (iOS Keychain / Android
/// Keystore — a real secret store). On web there's no OS-level equivalent:
/// [FlutterSecureStorage]'s web implementation just AES-GCM-wraps values
/// with a key that's itself stored client-side, so it adds complexity
/// without a real security benefit there, and its key handling has proven
/// unreliable across browser sessions. Plain [SharedPreferences] (backed by
/// localStorage on web) is used on web instead.
class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'current_user';

  /// On web, the refresh token itself is deliberately never persisted here —
  /// the backend also sets it as an HttpOnly cookie (see auth.routes.ts),
  /// which JS can't read even via an XSS bug, unlike anything stored through
  /// [SharedPreferences]/localStorage. Mobile has no such gap (this API's
  /// [FlutterSecureStorage] path is a real OS keychain), so it keeps storing
  /// it and using it exactly as before.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _write(_accessTokenKey, accessToken),
      if (!kIsWeb) _write(_refreshTokenKey, refreshToken),
    ]);
  }

  Future<String?> getAccessToken() => _readSafe(_accessTokenKey);

  /// Always null on web by design — see [saveTokens].
  Future<String?> getRefreshToken() => _readSafe(_refreshTokenKey);

  Future<void> saveUser(UserModel user) async {
    await _write(_userKey, jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    final json = await _readSafe(_userKey);
    if (json == null) return null;
    return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_accessTokenKey),
        prefs.remove(_refreshTokenKey),
        prefs.remove(_userKey),
      ]);
      return;
    }
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userKey),
    ]);
  }

  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    await _storage.write(key: key, value: value);
  }

  /// Treats any read failure as "nothing stored" rather than crashing the
  /// caller (relevant on mobile if an OS keychain entry is ever corrupt).
  Future<String?> _readSafe(String key) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key);
      }
      return await _storage.read(key: key);
    } catch (_) {
      await clearAll();
      return null;
    }
  }
}
