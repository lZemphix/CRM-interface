import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/main.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/bootstrap/modules.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CRM starts at the sign-in screen', (tester) async {
    final store = SessionStore();
    final client = ApiClient(store);
    await tester.pumpWidget(
      MyApp(
        authRepository: AuthRepository(client, store),
        modules: createModuleRegistry(client),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Войти'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
    await client.fresh.close();
    client.dio.close(force: true);
  });
}
