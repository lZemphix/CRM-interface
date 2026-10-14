import 'dart:async';

import 'package:crm_interface/app.dart';
import 'package:crm_interface/bootstrap/app_runtime.dart';
import 'package:crm_interface/bootstrap/server_app.dart';
import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/connection/server_probe.dart';
import 'package:crm_interface/core/modules/module_registry.dart';
import 'package:crm_interface/core/settings/server_settings.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_dio/fresh_dio.dart';

class MemorySettings implements ServerSettingsStore {
  MemorySettings([this.url]);
  String? url;
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<String?> read() async {
    if (failRead) throw const ServerSettingsException();
    return url;
  }

  @override
  Future<void> write(String value) async {
    if (failWrite) throw const ServerSettingsException();
    url = value;
  }
}

class FakeProbe extends ServerProbe {
  final checked = <String>[];
  String? failure;
  Completer<void>? wait;
  @override
  Future<void> check(String url) async {
    checked.add(url);
    await wait?.future;
    if (failure != null) throw ServerConnectionException(failure!);
  }
}

class FailingSession extends SessionStore {
  FailingSession(String url) : super(serverUrl: url);
  @override
  Future<void> retire() async =>
      throw PlatformException(code: 'storage_unavailable');
}

class RuntimeFactory {
  final created = <AppRuntime>[];
  bool failRetire = false;
  AppRuntime create(String url) {
    final store = failRetire
        ? FailingSession(url)
        : SessionStore(serverUrl: url);
    final client = ApiClient(store, baseUrl: url);
    final runtime = AppRuntime.withDependencies(
      url: url,
      client: client,
      auth: AuthRepository(client, store),
      modules: ModuleRegistry([]),
    );
    created.add(runtime);
    return runtime;
  }
}

Future<void> enterServer(WidgetTester tester, String url) async {
  await tester.enterText(find.byKey(const Key('server-address')), url);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('save-server')));
  await tester.tap(find.byKey(const Key('save-server')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> mount(
    WidgetTester tester,
    MemorySettings settings,
    RuntimeFactory factory,
    FakeProbe probe, {
    List<String> args = const [],
    String compiledUrl = '',
  }) async {
    await tester.pumpWidget(
      ServerApp(
        arguments: args,
        settings: settings,
        createRuntime: factory.create,
        probe: probe,
        compiledUrl: compiledUrl,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'first startup prompts; successful save returns login and persists across restart',
    (tester) async {
      final settings = MemorySettings();
      final factory = RuntimeFactory();
      final probe = FakeProbe();
      await mount(tester, settings, factory, probe);
      expect(find.text('Подключение к серверу'), findsOneWidget);
      expect(factory.created, isEmpty);
      await enterServer(tester, ' https://crm.example/api/ ');
      expect(find.text('Войти'), findsOneWidget);
      expect(find.text('Сервер: https://crm.example/api'), findsOneWidget);
      expect(settings.url, 'https://crm.example/api');
      expect(probe.checked, ['https://crm.example/api']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await mount(tester, settings, factory, probe);
      expect(find.text('Войти'), findsOneWidget);
      expect(
        probe.checked,
        hasLength(1),
      ); // Do not block offline startup on health.
      expect(factory.created, hasLength(2));
      expect(await factory.created.last.client.sessionStore.read(), isNull);
    },
  );

  testWidgets(
    'priority is launch argument, saved address, explicit build define',
    (tester) async {
      for (final scenario in [
        (
          ['--api-url=https://launch.example'],
          'https://saved.example',
          'https://build.example',
          'https://launch.example',
        ),
        (
          <String>[],
          'https://saved.example',
          'https://build.example',
          'https://saved.example',
        ),
        (<String>[], null, 'https://build.example', 'https://build.example'),
      ]) {
        final settings = MemorySettings(scenario.$2);
        final factory = RuntimeFactory();
        await mount(
          tester,
          settings,
          factory,
          FakeProbe(),
          args: scenario.$1,
          compiledUrl: scenario.$3,
        );
        expect(factory.created.single.url, scenario.$4);
        expect(
          settings.url,
          scenario.$2,
        ); // Overrides are not silently persisted.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  for (final corrupt in [false, true]) {
    testWidgets('recoverable configuration error (corrupt URL: $corrupt)', (
      tester,
    ) async {
      final settings = MemorySettings(corrupt ? 'invalid' : null)
        ..failRead = !corrupt;
      final factory = RuntimeFactory();
      await mount(tester, settings, factory, FakeProbe());
      expect(find.byKey(const Key('server-address')), findsOneWidget);
      expect(factory.created, isEmpty);
      await enterServer(tester, 'https://fixed.example');
      expect(find.text('Войти'), findsOneWidget);
    });
  }

  testWidgets(
    'failed probe or invalid URL never saves or destroys the existing runtime',
    (tester) async {
      final settings = MemorySettings('https://old.example');
      final factory = RuntimeFactory();
      final probe = FakeProbe()..failure = 'Сервер недоступен';
      await mount(tester, settings, factory, probe);
      await tester.tap(find.byKey(const Key('configure-server')));
      await tester.pumpAndSettle();
      await enterServer(tester, 'bad address');
      expect(probe.checked, isEmpty);
      await enterServer(tester, 'https://offline.example');
      expect(find.text('Сервер недоступен'), findsOneWidget);
      expect(settings.url, 'https://old.example');
      expect(factory.created.single.retired, isFalse);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(find.text('Войти'), findsOneWidget);
      expect(factory.created, hasLength(1));
    },
  );

  testWidgets('HTTP requires explicit warning acknowledgement', (tester) async {
    final settings = MemorySettings();
    final factory = RuntimeFactory();
    final probe = FakeProbe();
    await mount(tester, settings, factory, probe);
    await enterServer(tester, 'http://127.0.0.1:8000');
    expect(
      find.text('Подтвердите использование незащищённого HTTP.'),
      findsOneWidget,
    );
    expect(probe.checked, isEmpty);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-server')));
    await tester.pumpAndSettle();
    expect(settings.url, 'http://127.0.0.1:8000');
    expect(find.text('Войти'), findsOneWidget);
  });

  testWidgets(
    'saving is guarded and replaces auth, API and module graph with cleared tokens',
    (tester) async {
      final settings = MemorySettings('https://old.example');
      final factory = RuntimeFactory();
      final probe = FakeProbe()..wait = Completer<void>();
      await mount(tester, settings, factory, probe);
      final old = factory.created.single;
      final oldApp = tester.widget<MyApp>(find.byType(MyApp));
      await old.client.fresh.setToken(
        OAuth2Token(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          issuedAt: DateTime.now(),
          expiresIn: 900,
        ),
      );
      await tester.tap(find.byKey(const Key('configure-server')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('server-address')),
        'https://new.example/api/',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('save-server')));
      await tester.tap(find.byKey(const Key('save-server')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save-server')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Отмена'))
            .onPressed,
        isNull,
      );
      expect(probe.checked, hasLength(1));
      probe.wait!.complete();
      await tester.pumpAndSettle();
      final next = factory.created.last;
      expect(factory.created, hasLength(2));
      expect(old.retired, isTrue);
      expect(old.client.sessionStore.token, isNull);
      expect(await old.client.sessionStore.loadRefreshToken(), isNull);
      expect(next.client.sessionStore.token, isNull);
      expect(next.auth, isNot(same(old.auth)));
      expect(next.modules, isNot(same(old.modules)));
      expect(tester.widget<MyApp>(find.byType(MyApp)).key, isNot(oldApp.key));
      expect(settings.url, 'https://new.example/api');
      RequestOptions? sent;
      next.client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent = options;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {},
              ),
            );
          },
        ),
      );
      await tester.runAsync(() => next.client.dio.get<dynamic>('/probe'));
      expect(sent!.uri.toString(), 'https://new.example/api/probe');
      expect(
        sent!.headers.keys.any((key) => key.toLowerCase() == 'authorization'),
        isFalse,
      );
    },
  );

  testWidgets(
    'failed save leaves old address; cancellation recreates usable login',
    (tester) async {
      final settings = MemorySettings('https://old.example')..failWrite = true;
      final factory = RuntimeFactory();
      await mount(tester, settings, factory, FakeProbe());
      await tester.tap(find.byKey(const Key('configure-server')));
      await tester.pumpAndSettle();
      await enterServer(tester, 'https://new.example');
      expect(
        find.text('Не удалось сохранить адрес сервера. Повторите попытку.'),
        findsOneWidget,
      );
      expect(settings.url, 'https://old.example');
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(find.text('Сервер: https://old.example'), findsOneWidget);
      expect(factory.created.last.retired, isFalse);
    },
  );

  testWidgets('secure storage failure prevents switching and is visible', (
    tester,
  ) async {
    final settings = MemorySettings('https://old.example');
    final factory = RuntimeFactory()..failRetire = true;
    await mount(tester, settings, factory, FakeProbe());
    await tester.tap(find.byKey(const Key('configure-server')));
    await tester.pumpAndSettle();
    await enterServer(tester, 'https://new.example');
    expect(
      find.textContaining('Не удалось очистить защищённое хранилище.'),
      findsOneWidget,
    );
    expect(settings.url, 'https://old.example');
    expect(factory.created, hasLength(1));
    factory.failRetire = false;
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Войти'), findsOneWidget);
    expect(factory.created.last.url, 'https://old.example');
  });

  testWidgets('first setup fits a small window without a render overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, MemorySettings(), RuntimeFactory(), FakeProbe());
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('save-server')));
  });
}
