import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/employees/models/employee_forms.dart';
import 'package:crm_interface/modules/employees/repos/employees_repository.dart';
import 'package:crm_interface/modules/employees/widgets/create_employee.dart';
import 'package:crm_interface/modules/employees/widgets/create_employee_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class OptionsRepository extends EmployeesRepository {
  OptionsRepository() : super(ApiClient(SessionStore()));
  int reads = 0;
  bool fail = false;
  Completer<EmployeeFormOptions>? pending;
  EmployeeFormOptions options = EmployeeFormOptions(
    roles: [const EmployeeRoleChoice(id: 9, name: 'Роль')],
    branches: [],
  );
  @override
  Future<EmployeeFormOptions> getFormOptions() async {
    reads++;
    if (fail) throw const EmployeeFormFailure('Недостаточно прав');
    return pending?.future ?? options;
  }
}

void main() {
  late OptionsRepository repository;
  setUp(() => repository = OptionsRepository());
  tearDown(() => repository.apiClient.dio.close(force: true));
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CreateEmployeeFlow(
                  repository: repository,
                  onCreate: (_) async => const EmployeeCreatedView(
                    fullName: 'Тест',
                    login: 'test.user',
                    temporaryPassword: 'test-only-result',
                  ),
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pump();
  }

  testWidgets(
    'catalog loading and failure have a working retry without premature creation',
    (tester) async {
      repository.fail = true;
      await open(tester);
      await tester.pumpAndSettle();
      expect(find.text('Недостаточно прав'), findsOneWidget);
      expect(find.byType(CreateEmployeeDialog), findsNothing);
      repository.fail = false;
      repository.pending = Completer<EmployeeFormOptions>();
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(repository.reads, 2);
      repository.pending!.complete(repository.options);
      await tester.pumpAndSettle();
      expect(find.byType(CreateEmployeeDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty roles cannot submit and empty branches are honestly described',
    (tester) async {
      repository.options = EmployeeFormOptions(roles: [], branches: []);
      await open(tester);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Для создания сотрудника нужна роль'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('employee-create-submit')),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Филиалы'));
      await tester.tap(find.text('Филиалы'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Активных филиалов нет'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalog response after closing does not revive the dialog', (
    tester,
  ) async {
    repository.pending = Completer<EmployeeFormOptions>();
    await open(tester);
    await tester.pump();
    await tester.tap(find.text('Отмена'));
    await tester.pump();
    repository.pending!.complete(repository.options);
    await tester.pumpAndSettle();
    expect(find.byType(CreateEmployeeDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
