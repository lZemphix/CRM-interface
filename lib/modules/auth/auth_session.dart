import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fresh_dio/fresh_dio.dart';
import 'package:crm_interface/core/api_client/endpoint.dart';

class SessionStore implements TokenStorage<OAuth2Token> {
  SessionStore({FlutterSecureStorage? storage, String? serverUrl})
    : _refreshKey = serverUrl == null
          ? 'refresh_token'
          : 'refresh_token@${Uri.encodeComponent(ApiEndpoint.validate(serverUrl))}',
      _storage =
          storage ??
          const FlutterSecureStorage(
            // App-private macOS Keychain; no machine-bound provisioning profile.
            // Other platforms retain their existing secure-storage implementation.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;
  final String _refreshKey;
  final Set<Future<void>> _pendingWrites = {};
  bool _retired = false;

  OAuth2Token? token;

  Future<String?> loadRefreshToken() {
    return _storage.read(key: _refreshKey);
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
    await _storage.delete(key: _refreshKey);
  }

  @override
  Future<OAuth2Token?> read() async {
    return token;
  }

  @override
  Future<void> write(OAuth2Token newToken) {
    final operation = _write(newToken);
    _pendingWrites.add(operation);
    operation.then<void>(
      (_) => _pendingWrites.remove(operation),
      onError: (Object error, StackTrace stack) {
        _pendingWrites.remove(operation);
      },
    );
    return operation;
  }

  Future<void> _write(OAuth2Token newToken) async {
    if (_retired) throw StateError('Session has been retired');
    await _storage.write(key: _refreshKey, value: newToken.refreshToken);
    if (_retired) throw StateError('Session has been retired');
    token = newToken;
  }

  /// Wait for an already-started write before deletion: it must not resurrect
  /// credentials after a server change. The caller still receives write errors.
  Future<void> retire() async {
    _retired = true;
    token = null;
    for (final write in _pendingWrites.toList()) {
      try {
        await write;
      } on Object {
        // Only draining here; the original operation reports its own failure.
      }
    }
    await delete();
  }

  Future<void> clearLegacyToken() async {
    if (_refreshKey != 'refresh_token') {
      await _storage.delete(key: 'refresh_token');
    }
  }
}
