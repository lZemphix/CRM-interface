import 'dart:async';

import 'package:crm_interface/modules/employees/models/employee_forms.dart';
import 'package:crm_interface/modules/employees/widgets/archive_employee.dart';
import 'package:crm_interface/modules/employees/widgets/create_employee.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const roles = [
  EmployeeRoleChoice(
    id: 9,
    name: 'Тестовая роль',
    description: 'Описание тестовой роли',
  ),
];
const branches = [
  EmployeeBranchChoice(id: 1, name: 'Первый'),
  EmployeeBranchChoice(id: 2, name: 'Второй'),
];
const employee = EmployeeArchiveView(
  id: 7,
  fullName: 'Тестовый Сотрудник',
  login: 'test.user',
  roleName: 'Тестовая роль',
  openTasks: 2,
  version: 12,
);

void main() {
  Future<void> open(WidgetTester tester, Widget dialog) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showDialog<void>(context: context, builder: (_) => dialog),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  Future<void> createFields(WidgetTester tester) async {
    await enter(tester, 'employee-name', 'Тестовый Сотрудник');
    await enter(tester, 'employee-login', 'TEST.user');
    final role = find.byKey(const Key('employee-role'));
    await tester.ensureVisible(role);
    await tester.tap(role);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тестовая роль').last);
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String key) async {
    final button = find.byKey(Key(key));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  test('login validation accepts the agreed characters and rejects unsafe/empty input', () {
    for (final login in ['TEST.user', 'user-name', 'a_b', '  abc  ']) {
      expect(validateEmployeeLogin(login), isNull);
    }
    for (final login in [
      null,
      '',
      '  ',
      'ab',
      'имя',
      '_abc',
      'bad login',
      'a' * 129,
    ]) {
      expect(validateEmployeeLogin(login), isNotNull);
    }
  });

  testWidgets(
    'unconnected creation has no fabricated roles or successful submission',
    (tester) async {
      await open(tester, const CreateEmployeeDialog());
      await enter(tester, 'employee-name', 'Тестовый Сотрудник');
      await enter(tester, 'employee-login', 'abc');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('employee-create-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('API не подключён'), findsOneWidget);
      expect(find.text('Сотрудник создан'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('employee-branches')));
      await tester.tap(find.text('Филиалы'));
      await tester.pumpAndSettle();
      expect(
        find.text('Филиалы появятся после подключения API.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'creation validates, emits typed data and blocks dismissal and duplicates while pending',
    (tester) async {
      final pending = Completer<EmployeeCreatedView>();
      EmployeeCreateDraft? draft;
      var calls = 0;
      await open(
        tester,
        CreateEmployeeDialog(
          roles: roles,
          branches: branches,
          onCreate: (value) {
            calls++;
            draft = value;
            return pending.future;
          },
        ),
      );
      await press(tester, 'employee-create-submit');
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Укажите ФИО'), findsOneWidget);
      await createFields(tester);
      await tester.ensureVisible(find.text('Филиалы'));
      await tester.tap(find.text('Филиалы'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Первый'));
      await tester.tap(find.widgetWithText(FilterChip, 'Первый'));
      await tester.pumpAndSettle();
      expect(find.text('Основной филиал'), findsOneWidget);
      await press(tester, 'employee-create-submit');
      expect(calls, 1);
      expect(draft!.fullName, 'Тестовый Сотрудник');
      expect(draft!.login, 'test.user');
      expect(draft!.roleId, 9);
      expect(draft!.branchIds, [1]);
      expect(draft!.primaryBranchId, isNull);
      expect(() => draft!.branchIds.add(2), throwsUnsupportedError);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('employee-create-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('employee-dialog-close')))
            .onPressed,
        isNull,
      );
      pending.complete(
        const EmployeeCreatedView(
          fullName: 'Тестовый Сотрудник',
          login: 'test.user',
          temporaryPassword: 'test-only-result',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Сотрудник создан'), findsOneWidget);
      final field = find.byKey(const Key('employee-temporary-password'));
      final controller = tester.widget<TextField>(field).controller!;
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      await tester.ensureVisible(find.byTooltip('Показать пароль'));
      await tester.tap(find.byTooltip('Показать пароль'));
      await tester.pump();
      expect(tester.widget<TextField>(field).obscureText, isFalse);
      await tester.ensureVisible(find.text('Готово'));
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(controller.text, '');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'creation preserves draft and blocks blind retry on an uncertain outcome',
    (tester) async {
      var calls = 0;
      await open(
        tester,
        CreateEmployeeDialog(
          roles: roles,
          onCreate: (_) async {
            calls++;
            throw const EmployeeFormFailure(
              'Исход неизвестен. Не повторяйте создание.',
              retryAllowed: false,
            );
          },
        ),
      );
      await createFields(tester);
      await press(tester, 'employee-create-submit');
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('Исход неизвестен'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('employee-name')))
            .controller!
            .text,
        'Тестовый Сотрудник',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('employee-create-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clipboard refusal is shown without claiming success', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(
      tester,
      CreateEmployeeDialog(
        roles: roles,
        onCreate: (_) async => const EmployeeCreatedView(
          fullName: 'Тест',
          login: 'test.user',
          temporaryPassword: 'test-only-result',
        ),
      ),
    );
    await createFields(tester);
    await press(tester, 'employee-create-submit');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Скопировать данные'));
    await tester.tap(find.text('Скопировать данные'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Копирование недоступно'), findsOneWidget);
    expect(find.textContaining('Данные скопированы'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unconnected archive accepts manual input but never invents an employee',
    (tester) async {
      await open(tester, const ArchiveEmployeeDialog());
      await enter(tester, 'employee-archive-login', 'test.user');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('employee-archive-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('API не подключён'), findsOneWidget);
      expect(find.byType(Autocomplete<String>), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'archive is exact lookup followed by explicit confirmation carrying the version',
    (tester) async {
      final queries = <String>[];
      EmployeeArchiveView? archived;
      await open(
        tester,
        ArchiveEmployeeDialog(
          onLookup: (login) async {
            queries.add(login);
            return employee;
          },
          onArchive: (value) async {
            archived = value;
          },
        ),
      );
      await enter(tester, 'employee-archive-login', ' TEST.USER ');
      await press(tester, 'employee-archive-submit');
      await tester.pumpAndSettle();
      expect(queries, ['test.user']);
      expect(archived, isNull);
      expect(find.text('Тестовый Сотрудник'), findsOneWidget);
      expect(find.textContaining('Открытых задач: 2'), findsOneWidget);
      await enter(tester, 'employee-archive-login', 'other.user');
      expect(find.text('Тестовый Сотрудник'), findsNothing);
      expect(find.text('Продолжить'), findsOneWidget);
      await enter(tester, 'employee-archive-login', 'test.user');
      await press(tester, 'employee-archive-submit');
      await tester.pumpAndSettle();
      await press(tester, 'employee-archive-submit');
      await tester.pumpAndSettle();
      expect(archived, same(employee));
      expect(archived!.version, 12);
      expect(find.byType(ArchiveEmployeeDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lookup failures preserve login and pending lookup survives disposal safely',
    (tester) async {
      var fail = true;
      final pending = Completer<EmployeeArchiveView>();
      await open(
        tester,
        ArchiveEmployeeDialog(
          onLookup: (_) {
            if (fail) throw const EmployeeFormFailure('Сотрудник не найден');
            return pending.future;
          },
        ),
      );
      await enter(tester, 'employee-archive-login', 'test.user');
      await press(tester, 'employee-archive-submit');
      await tester.pumpAndSettle();
      expect(find.text('Сотрудник не найден'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('employee-archive-login')),
            )
            .controller!
            .text,
        'test.user',
      );
      fail = false;
      await press(tester, 'employee-archive-submit');
      await tester.pumpWidget(const SizedBox());
      pending.complete(employee);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [360.0, 800.0]) {
    testWidgets('employee forms fit width $width and a short window', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, const CreateEmployeeDialog());
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('employee-dialog-close')));
      await tester.pumpAndSettle();
      await open(tester, const ArchiveEmployeeDialog());
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(Dialog));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(width));
    });
  }
}
