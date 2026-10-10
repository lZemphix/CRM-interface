import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/bootstrap/modules.g.dart';
import 'package:crm_interface/layout/app_shell.dart';
import 'package:crm_interface/layout/sidebar.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/models/profile.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/modules/auth/screens/auth_screen.dart';
import 'package:crm_interface/modules/auth/screens/session_gate.dart';
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_dio/fresh_dio.dart';

const profile = AuthProfile(
  id: 1,
  login: 'test-user',
  fullName: 'Анна Петрова Сергеевна',
  roleName: 'Администратор',
);

class MemorySessionStore extends SessionStore {
  int deletes = 0;

  @override
  Future<void> write(OAuth2Token value) async => token = value;

  @override
  Future<void> delete() async {
    deletes++;
    token = null;
  }
}

class ProfileRepository extends AuthRepository {
  ProfileRepository(super.apiClient, super.sessionStore);

  int reads = 0;
  bool fail = false;
  Completer<AuthProfile>? pending;

  @override
  Future<AuthProfile> getProfile() async {
    reads++;
    if (fail) throw const FormatException('Invalid profile');
    if (pending != null) return pending!.future;
    return profile;
  }
}

ApiClient makeClient({
  bool logoutFails = false,
  Future<void>? logoutPending,
  VoidCallback? onLogoutRequested,
}) {
  final api = ApiClient(MemorySessionStore());
  addTearDown(() => api.dio.close(force: true));
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.path == '/customers') {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {'items': [], 'total': 0, 'limit': 50, 'offset': 0},
            ),
          );
        } else if (options.path == '/auth/logout') {
          onLogoutRequested?.call();
          if (logoutPending != null) await logoutPending;
          if (logoutFails) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<void>(
                  requestOptions: options,
                  statusCode: 503,
                ),
              ),
            );
          } else {
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 204),
            );
          }
        } else {
          handler.reject(DioException(requestOptions: options));
        }
      },
    ),
  );
  return api;
}

Future<void> openShell(
  WidgetTester tester,
  ProfileRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AppShell(
        modules: createModuleRegistry(repository.apiClient),
        authRepository: repository,
      ),
    ),
  );
  await tester.pump();
}

Future<void> openGatedShell(WidgetTester tester, ProfileRepository repo) async {
  await repo.apiClient.fresh.setToken(
    OAuth2Token(
      accessToken: 'test-access',
      refreshToken: 'test-refresh',
      issuedAt: DateTime.now(),
      expiresIn: 900,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: SessionGate(
        authRepository: repo,
        authenticatedBuilder: (_) => AppShell(
          modules: createModuleRegistry(repo.apiClient),
          authRepository: repo,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  tester.widget<AuthScreen>(find.byType(AuthScreen)).onAuthenticated();
  await tester.pumpAndSettle();
}

void main() {
  test(
    'account initials use two words or two graphemes from a single word',
    () {
      expect(accountInitials('Анна Петрова'), 'АП');
      expect(accountInitials('  анна\tпетрова  Сергеевна '), 'АП');
      expect(accountInitials('Анна'), 'АН');
      expect(accountInitials('А'), 'А');
      expect(accountInitials('  '), '?');
      expect(accountInitials('👩‍💻 Разработчик'), '👩‍💻Р');
      expect(accountInitials('👩‍💻Dev'), '👩‍💻D');
    },
  );

  for (final height in [600.0, 300.0]) {
    testWidgets('bottom actions remain visible at height $height', (
      tester,
    ) async {
      var taps = 0;
      String? selected;
      final modules = createModuleRegistry(makeClient());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: height,
              child: SideBar(
                modules: modules.modules,
                activeModuleId: 'customers',
                onModuleSelected: (id) => selected = id,
                accountProfile: profile,
                onLogout: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final avatar = find.byKey(const Key('sidebar-account'));
      final settings = find.byKey(const Key('sidebar-settings'));
      expect(find.text('АП'), findsOneWidget);
      expect(tester.getSize(avatar), const Size(44, 44));
      expect(tester.getBottomLeft(settings).dy, closeTo(height - 16, 0.1));
      expect(
        tester.getBottomLeft(avatar).dy,
        lessThan(tester.getTopLeft(settings).dy),
      );
      expect(tester.widget<IconButton>(settings).onPressed, isNull);
      expect(find.byTooltip('Параметры — пока не реализованы'), findsOneWidget);
      await tester.tap(avatar);
      await tester.pumpAndSettle();
      expect(find.text('Об аккаунте'), findsOneWidget);
      expect(find.text('Настройки аккаунта'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final settingsItem = tester.widget<MenuItemButton>(
        find.widgetWithText(MenuItemButton, 'Настройки аккаунта'),
      );
      expect(settingsItem.onPressed, isNull);
      await tester.tap(find.text('Выход'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      final analytics = find.byIcon(Icons.analytics_outlined);
      await tester.ensureVisible(analytics);
      await tester.tap(analytics);
      expect(selected, 'analytics');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('account menu closes outside but survives overlay transitions', (
    tester,
  ) async {
    final api = makeClient();
    final repo = ProfileRepository(api, api.sessionStore);
    await openShell(tester, repo);
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 100));
    addTearDown(mouse.removePointer);
    final avatar = find.byKey(const Key('sidebar-account'));
    await mouse.moveTo(tester.getCenter(avatar));
    await tester.pumpAndSettle();
    expect(find.text('Об аккаунте'), findsNothing);
    await tester.tap(avatar);
    await tester.pumpAndSettle();
    final about = find.text('Об аккаунте');
    final menuButton = find.widgetWithText(MenuItemButton, 'Выход');
    final gap = Offset(
      (tester.getRect(avatar).right + tester.getRect(menuButton).left) / 2,
      tester.getCenter(avatar).dy,
    );
    await mouse.moveTo(gap);
    await tester.pump(const Duration(milliseconds: 100));
    await mouse.moveTo(tester.getCenter(menuButton));
    await tester.pump(const Duration(milliseconds: 300));
    expect(about, findsOneWidget);

    await mouse.moveTo(tester.getCenter(about));
    await tester.pumpAndSettle();
    final identity = find.text('Логин: test-user');
    expect(identity, findsOneWidget);
    await mouse.moveTo(tester.getCenter(identity));
    await tester.pump(const Duration(milliseconds: 300));
    expect(about, findsOneWidget);
    expect(identity, findsOneWidget);
    // Also cover the padded edge of the root menu, not only menu items.
    final rootRegion = find
        .ancestor(of: about, matching: find.byType(MouseRegion))
        .last;
    await mouse.moveTo(
      tester.getRect(rootRegion).bottomCenter - const Offset(0, 1),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(about, findsOneWidget);
    await mouse.moveTo(const Offset(700, 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(about, findsNothing);
    expect(identity, findsNothing);

    // Reopening must not retain hovered regions of the removed overlays.
    await mouse.moveTo(tester.getCenter(avatar));
    await tester.tap(avatar);
    await tester.pumpAndSettle();
    await mouse.moveTo(tester.getCenter(menuButton));
    await tester.pump();
    await mouse.moveTo(const Offset(-10, -10));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(about, findsNothing);

    await mouse.moveTo(tester.getCenter(avatar));
    await tester.tap(avatar);
    await tester.pumpAndSettle();
    await mouse.moveTo(const Offset(700, 100));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile loads once and account opens server identity', (
    tester,
  ) async {
    final api = makeClient();
    final repo = ProfileRepository(api, api.sessionStore);
    final pending = Completer<AuthProfile>();
    repo.pending = pending;
    await openShell(tester, repo);
    final avatar = find.byKey(const Key('sidebar-account'));
    expect(tester.widget<TextButton>(avatar).onPressed, isNotNull);
    expect(find.byTooltip('Загрузка профиля…'), findsOneWidget);
    pending.complete(profile);
    await tester.pumpAndSettle();
    expect(find.text('АП'), findsOneWidget);
    await tester.tap(avatar);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Об аккаунте'), findsOneWidget);
    await tester.tap(find.text('Об аккаунте'));
    await tester.pumpAndSettle();
    expect(find.text(profile.fullName), findsOneWidget);
    expect(find.text('Логин: test-user'), findsOneWidget);
    expect(find.text('Роль: Администратор'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.analytics_outlined));
    await tester.pumpAndSettle();
    expect(find.text('analytics'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('catalog'), findsOneWidget);
    expect(repo.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile failure does not block CRM and avatar retries', (
    tester,
  ) async {
    final api = makeClient();
    final repo = ProfileRepository(api, api.sessionStore)..fail = true;
    await openShell(tester, repo);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Аккаунт — профиль недоступен'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.analytics_outlined));
    await tester.pumpAndSettle();
    expect(find.text('analytics'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.byKey(const Key('sidebar-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Об аккаунте'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повторить загрузку профиля'));
    await tester.pumpAndSettle();
    expect(find.text('АП'), findsOneWidget);
    expect(repo.reads, 2);
    expect(tester.takeException(), isNull);
  });

  for (final fail in [false, true]) {
    testWidgets('account logout returns to login (server fails=$fail)', (
      tester,
    ) async {
      var requests = 0;
      final pending = Completer<void>();
      final api = makeClient(
        logoutFails: fail,
        logoutPending: pending.future,
        onLogoutRequested: () => requests++,
      );
      final repo = ProfileRepository(api, api.sessionStore)..fail = true;
      await openGatedShell(tester, repo);
      // Logout must remain available even when /auth/me failed.
      await tester.tap(find.byKey(const Key('sidebar-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выход'));
      await tester.pump();
      // MenuItemButton closes the overlay before dispatching its action.
      await tester.pump(const Duration(milliseconds: 200));
      expect(requests, 1);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('sidebar-account')))
            .onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(await api.fresh.token, isNull);
      expect(api.sessionStore.token, isNull);
      expect((api.sessionStore as MemorySessionStore).deletes, 1);
      expect(requests, 1);
      if (fail) {
        expect(
          find.text(
            'Локальный выход выполнен, но серверный выход не подтверждён',
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final valid in [true, false]) {
    test('auth profile GET uses confirmed contract (valid=$valid)', () async {
      final api = makeClient();
      api.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/auth/me');
            expect(options.method, 'GET');
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 1,
                  'login': 'test-user',
                  'full_name': 'Анна Петрова Сергеевна',
                  'role': valid
                      ? {'id': 1, 'code': 'admin', 'name': 'Администратор'}
                      : null,
                  'permissions': [],
                  'branches': [],
                  'must_change_password': false,
                },
              ),
            );
          },
        ),
      );
      final result = AuthRepository(api, api.sessionStore).getProfile();
      if (valid) {
        final loaded = await result;
        expect(loaded.id, profile.id);
        expect(loaded.login, profile.login);
        expect(loaded.fullName, profile.fullName);
        expect(loaded.roleName, profile.roleName);
      } else {
        await expectLater(result, throwsFormatException);
      }
    });
  }
}
