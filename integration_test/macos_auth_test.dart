import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/main.dart';
import 'package:crm_interface/layout/app_shell.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/bootstrap/modules.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native Keychain, real login, password change, clients and tasks',
    (tester) async {
      const url = String.fromEnvironment('CRM_TEST_API_URL');
      const login = String.fromEnvironment('CRM_TEST_LOGIN');
      const password = String.fromEnvironment('CRM_TEST_PASSWORD');
      const newPassword = String.fromEnvironment('CRM_TEST_NEW_PASSWORD');
      expect(url, isNotEmpty, reason: 'Use an isolated test backend');
      expect(password, isNotEmpty);
      // Separate service prevents the test from touching the user session.
      const storage = FlutterSecureStorage(
        mOptions: MacOsOptions(
          usesDataProtectionKeychain: false,
          accountName: 'crm-macos-integration-test',
        ),
      );
      final store = SessionStore(storage: storage);
      final client = ApiClient(store, baseUrl: url);
      final repository = AuthRepository(client, store);
      try {
        await store.delete();
        await tester.pumpWidget(
          MyApp(
            authRepository: repository,
            modules: createModuleRegistry(client),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), login);
        await tester.enterText(find.byType(TextFormField).at(1), password);
        await tester.tap(find.text('Войти'));
        for (
          var i = 0;
          i < 80 && find.text('Смена временного пароля').evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(find.text('Смена временного пароля'), findsOneWidget);
        // A new store instance must read the token written by the real plugin.
        final restored = await SessionStore(storage: storage)
            .loadRefreshToken();
        expect(
          restored != null && restored == store.token?.refreshToken,
          isTrue,
          reason: 'Keychain round-trip failed (token intentionally not logged)',
        );
        await tester.enterText(find.byType(TextFormField).at(0), password);
        await tester.enterText(find.byType(TextFormField).at(1), newPassword);
        await tester.enterText(find.byType(TextFormField).at(2), newPassword);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Сменить пароль'));
        for (
          var i = 0;
          i < 80 && find.byType(AppShell).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(find.byType(AppShell), findsOneWidget);
        await tester.pumpAndSettle();
        final customers = await client.dio.get<Map<String, dynamic>>(
          '/customers',
        );
        expect((customers.data?['items'] as List).isNotEmpty, isTrue);
        final tasks = await client.dio.get<Map<String, dynamic>>('/tasks');
        expect((tasks.data?['items'] as List).isNotEmpty, isTrue);
        await tester.tap(find.byIcon(Icons.task_alt_outlined));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await repository.logout();
        await tester.pumpAndSettle();
        expect(
          await SessionStore(storage: storage).loadRefreshToken() == null,
          isTrue,
        );
        expect(find.text('Войти'), findsOneWidget);
      } finally {
        await store.delete();
        await tester.pumpWidget(const SizedBox.shrink());
        await client.fresh.close();
        client.dio.close(force: true);
      }
    },
  );
}
