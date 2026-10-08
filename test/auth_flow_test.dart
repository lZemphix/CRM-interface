import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/modules/auth/screens/auth_screen.dart';
import 'package:crm_interface/modules/auth/screens/password_change.dart';
import 'package:crm_interface/modules/auth/screens/session_gate.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_dio/fresh_dio.dart';

class FakeSessionStore extends SessionStore {
  @override
  Future<OAuth2Token?> read() async => token;

  @override
  Future<void> write(OAuth2Token newToken) async => token = newToken;

  @override
  Future<void> delete() async => token = null;
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository(SessionStore store, {this.mustChangePassword = true})
    : super(ApiClient(store), store) {
    apiClient.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/customers') {
            handler.resolve(
              Response<List<dynamic>>(requestOptions: options, data: []),
            );
            return;
          }
          if (options.path == '/auth/logout') {
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 204),
            );
            return;
          }
          handler.next(options);
        },
      ),
    );
  }

  final bool mustChangePassword;
  String? currentPassword;
  String? newPassword;

  @override
  Future<bool> auth({required String login, required String password}) async {
    if (!mustChangePassword) {
      await apiClient.fresh.setToken(
        OAuth2Token(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
          issuedAt: DateTime.now(),
          expiresIn: 900,
        ),
      );
    }
    return mustChangePassword;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    this.currentPassword = currentPassword;
    this.newPassword = newPassword;
  }
}

void main() {
  testWidgets('temporary password opens password change form', (tester) async {
    final repository = FakeAuthRepository(FakeSessionStore());
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(authRepository: repository, onAuthenticated: () {}),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'temporary password',
    );
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Смена временного пароля'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets('password change submits current and new password', (
    tester,
  ) async {
    final repository = FakeAuthRepository(FakeSessionStore());
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeFormScreen(
          authRepository: repository,
          onPasswordChanged: () => completed = true,
          onReturnToLogin: () {},
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'temporary password',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'a new secure password',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'a new secure password',
    );
    await tester.tap(find.text('Сменить пароль'));
    await tester.pumpAndSettle();

    expect(repository.currentPassword, 'temporary password');
    expect(repository.newPassword, 'a new secure password');
    expect(completed, isTrue);
  });

  testWidgets('lost session replaces CRM with login', (tester) async {
    final repository = FakeAuthRepository(
      FakeSessionStore(),
      mustChangePassword: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SessionGate(
          authRepository: repository,
          authenticatedBuilder: (context) =>
              const Scaffold(body: Text('CRM открыт')),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('CRM открыт'), findsOneWidget);

    await repository.apiClient.fresh.clearToken();
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('CRM открыт'), findsNothing);
  });

  test('logout clears local token after server confirms 204', () async {
    final store = FakeSessionStore();
    final repository = FakeAuthRepository(store);
    await repository.apiClient.fresh.setToken(
      OAuth2Token(
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        issuedAt: DateTime.now(),
        expiresIn: 900,
      ),
    );

    await repository.logout();

    expect(await repository.apiClient.fresh.token, isNull);
    expect(await store.read(), isNull);
  });
}
