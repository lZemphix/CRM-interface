import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/api_client/endpoint.dart';
import 'package:crm_interface/core/connection/server_probe.dart';
import 'package:crm_interface/core/settings/server_settings.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_dio/fresh_dio.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class ProbeAdapter implements HttpClientAdapter {
  ProbeAdapter(this.body, {this.status = 200});
  final Object body;
  final int status;
  RequestOptions? request;
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) => closed = true;
}

class DelayedStorage extends FlutterSecureStorage {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    entered.complete();
    await release.future;
    await super.write(key: key, value: value);
  }
}

OAuth2Token token(String name) => OAuth2Token(
  accessToken: '$name-access',
  refreshToken: '$name-refresh',
  issuedAt: DateTime.now(),
  expiresIn: 900,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'preference survives a new store instance and preserves unrelated keys',
    () async {
      final first = PreferencesServerSettings();
      expect(await first.read(), isNull);
      await first.write(' https://crm.example/api/// ');
      expect(
        await PreferencesServerSettings().read(),
        'https://crm.example/api',
      );
      expect(
        () => first.write('https://user:pass@crm.example'),
        throwsFormatException,
      );
    },
  );

  test('wrong preference type becomes recoverable settings error', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          PreferencesServerSettings.key: 42,
        });
    await expectLater(
      PreferencesServerSettings().read(),
      throwsA(isA<ServerSettingsException>()),
    );
  });

  test(
    'URL arguments stay optional and reject ambiguous or unsafe addresses',
    () {
      expect(ApiEndpoint.argumentOverride([]), isNull);
      for (final args in [
        ['--api-url'],
        ['--api-url='],
        ['--api-url=https://one.example', '--api-url=https://two.example'],
      ]) {
        expect(() => ApiEndpoint.argumentOverride(args), throwsFormatException);
      }
      for (final url in [
        'https://foo bar',
        r'https://foo\bar',
        'https://crm.example/path name',
        'https://crm.example?secret=value',
      ]) {
        expect(() => ApiEndpoint.validate(url), throwsFormatException);
      }
      expect(
        ApiEndpoint.validate('http://[::1]:8000/api/'),
        'http://[::1]:8000/api',
      );
    },
  );

  test(
    'health probe is unauthenticated, bounded, keeps path and closes Dio',
    () async {
      final adapter = ProbeAdapter({'status': 'ok'});
      final probe = ServerProbe(
        createDio: () => Dio()..httpClientAdapter = adapter,
      );
      await probe.check('https://crm.example/api/');
      final request = adapter.request!;
      expect(request.uri.toString(), 'https://crm.example/api/health');
      expect(request.followRedirects, isFalse);
      expect(
        request.headers.keys.any((key) => key.toLowerCase() == 'authorization'),
        isFalse,
      );
      expect(request.data, isNull);
      expect(request.connectTimeout, const Duration(seconds: 5));
      expect(request.receiveTimeout, const Duration(seconds: 5));
      expect(adapter.closed, isTrue);
    },
  );

  for (final response in [
    (200, <String, dynamic>{'status': 'wrong'}),
    (200, <String, dynamic>{}),
    (200, '<html>login</html>'),
    (302, <String, dynamic>{'status': 'ok'}),
    (404, <String, dynamic>{}),
    (503, <String, dynamic>{}),
  ]) {
    test(
      'health rejects unexpected reply ${response.$1} ${response.$2}',
      () async {
        final adapter = ProbeAdapter(response.$2, status: response.$1);
        final probe = ServerProbe(
          createDio: () => Dio()..httpClientAdapter = adapter,
        );
        await expectLater(
          probe.check('https://crm.example'),
          throwsA(isA<ServerConnectionException>()),
        );
        expect(adapter.closed, isTrue);
      },
    );
  }

  test('health network failure does not expose transport details', () async {
    final probe = ServerProbe(
      createDio: () => Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'private transport details',
              ),
            ),
          ),
        ),
    );
    await expectLater(
      probe.check('https://crm.example'),
      throwsA(
        isA<ServerConnectionException>().having(
          (error) => error.message,
          'safe message',
          isNot(contains('private transport')),
        ),
      ),
    );
  });

  test(
    'tokens are server-bound; legacy cleanup does not erase another server',
    () async {
      final first = SessionStore(serverUrl: 'https://first.example');
      final second = SessionStore(serverUrl: 'https://second.example');
      final legacy = SessionStore();
      await first.write(token('first'));
      await second.write(token('second'));
      await legacy.write(token('legacy'));
      await first.retire();
      await second.clearLegacyToken();
      expect(await first.read(), isNull);
      expect(await first.loadRefreshToken(), isNull);
      expect(await second.loadRefreshToken(), 'second-refresh');
      expect(await legacy.loadRefreshToken(), isNull);
      // No automatic login restoration was introduced.
      expect(
        await SessionStore(serverUrl: 'https://second.example').read(),
        isNull,
      );
      await expectLater(first.write(token('late')), throwsStateError);
    },
  );

  test(
    'late secure-storage write cannot resurrect a retired session',
    () async {
      final storage = DelayedStorage();
      final store = SessionStore(
        storage: storage,
        serverUrl: 'https://crm.example',
      );
      final write = store.write(token('late'));
      final failedWrite = expectLater(write, throwsStateError);
      await storage.entered.future;
      final retirement = store.retire();
      storage.release.complete();
      await failedWrite;
      await retirement;
      expect(await store.loadRefreshToken(), isNull);
      expect(store.token, isNull);
    },
  );

  test(
    'main and refresh clients reject redirects and support owned disposal',
    () async {
      final client = ApiClient(
        SessionStore(serverUrl: 'https://crm.example'),
        baseUrl: 'https://crm.example',
      );
      expect(client.dio.options.followRedirects, isFalse);
      await client.close();
      await client.close();
      await expectLater(
        client.dio.get<dynamic>('/customers'),
        throwsA(isA<DioException>()),
      );
    },
  );
}
