import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fresh_dio/fresh_dio.dart';

class SessionStore implements TokenStorage<OAuth2Token> {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

    OAuth2Token? token;

  Future<String?> loadRefreshToken() {
      return _storage.read(key: 'refresh_token');
    }

  OAuth2Token tokenFromApi(Map<String, dynamic> data) {
    final now = DateTime.now().toUtc();
    final expiresAt = DateTime.parse(data['access_expires_at'] as String)
        .toUtc();

    return OAuth2Token(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
      issuedAt: now,
      expiresIn: expiresAt.difference(now).inSeconds,
    );
  }

  @override
  Future<void> delete() async {
      token = null;
      await _storage.delete(key: 'refresh_token');
    }

  @override
  Future<OAuth2Token?> read() async {
    return token;
  }

  @override
  Future<void> write(OAuth2Token newToken) async {
    await _storage.write(key: 'refresh_token', value: newToken.refreshToken);
    token = newToken;
  }
}
