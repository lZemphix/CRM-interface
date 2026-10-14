import 'dart:convert';
import 'dart:io';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/api_client/endpoint.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_dio/fresh_dio.dart';

class MemorySessionStore extends SessionStore {
  @override
  Future<void> write(OAuth2Token value) async => token = value;
  @override
  Future<void> delete() async => token = null;
}

void main() {
  test(
    'runtime URL overrides the build default and strips trailing slashes',
    () {
      expect(ApiEndpoint.fromArguments([]), ApiEndpoint.defaultUrl);
      expect(
        ApiEndpoint.fromArguments([
          '-psn_0_1',
          '--api-url=https://crm.example/api/',
        ]),
        'https://crm.example/api',
      );
    },
  );

  test('rejects invalid URLs, credentials and ambiguous overrides', () {
    for (final value in [
      '',
      'file:///tmp/crm',
      'http://',
      'https://user:password@crm.example',
      'https://crm.example?token=secret',
      'https://crm.example#fragment',
      'http://localhost:0',
      'http://localhost:99999',
    ]) {
      expect(() => ApiEndpoint.validate(value), throwsFormatException);
    }
    expect(
      () => ApiEndpoint.fromArguments([
        '--api-url=http://localhost:8000',
        '--api-url=http://localhost:9000',
      ]),
      throwsFormatException,
    );
  });

  test('refresh and retried requests use the configured backend', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final paths = <String>[];
    server.listen((request) async {
      paths.add(request.uri.path);
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/auth/refresh') {
        request.response.write(
          jsonEncode({
            'access_token': 'rotated-access',
            'refresh_token': 'rotated-refresh',
            'token_type': 'bearer',
            'expires_in': 900,
            'access_expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 15))
                .toIso8601String(),
          }),
        );
      } else if (request.headers.value('Authorization')?.toLowerCase() !=
          'bearer rotated-access') {
        request.response.statusCode = 401;
        request.response.write('{}');
      } else {
        request.response.write('{"ok":true}');
      }
      await request.response.close();
    });
    final client = ApiClient(
      MemorySessionStore(),
      baseUrl: 'http://127.0.0.1:${server.port}',
    );
    try {
      await client.fresh.setToken(
        OAuth2Token(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          issuedAt: DateTime.now(),
          expiresIn: 900,
        ),
      );
      final response = await client.dio.get<Map<String, dynamic>>('/probe');
      expect(response.data, {'ok': true});
      expect(paths, ['/probe', '/auth/refresh', '/probe']);
      expect(client.sessionStore.token?.refreshToken, 'rotated-refresh');
    } finally {
      client.dio.close(force: true);
      await client.fresh.close();
      await server.close(force: true);
    }
  });
}
