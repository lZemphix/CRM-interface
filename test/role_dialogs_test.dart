import 'dart:async';

import 'package:crm_interface/core/modules/module_data_changes.dart';
import 'package:crm_interface/modules/employees/module.dart' as employees;
import 'package:crm_interface/modules/roles/module.dart' as roles;
import 'package:crm_interface/modules/roles/models/role.dart';
import 'package:crm_interface/modules/roles/repos/roles_repository.dart';
import 'package:crm_interface/modules/roles/widgets/create_role.dart';
import 'package:crm_interface/modules/roles/widgets/delete_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/roles_api.dart';

void main() {
  late RolesTestApi api;
  late RolesRepository repository;
  RoleInfo? created;
  int changes = 0;
  setUp(() {
    api = RolesTestApi();
    repository = RolesRepository(api.client);
    created = null;
    changes = 0;
  });
  tearDown(() => api.close());

  Future<void> open(WidgetTester tester, Widget dialog) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                created = await showDialog<RoleInfo>(
                  context: context,
                  builder: (_) => dialog,
                );
              },
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> roleFields(WidgetTester tester) async {
    await enter(tester, 'role-name', 'Новая роль');
    await enter(tester, 'role-code', 'new_role');
  }

  Future<void> selectRole(WidgetTester tester) async {
    await press(tester, find.byType(DropdownButtonFormField<int>));
    await press(tester, find.textContaining('Оператор (operator)').last);
    await press(tester, find.byKey(const Key('role-delete-submit')));
  }

  test('roles module exposes exactly two actions without a screen', () {
    final module = roles.createModule(api.client);
    expect(module.id, 'roles');
    expect(module.screenBuilder, isNull);
    expect(module.pinnedByDefault, isFalse);
    expect(module.actions.map((action) => action.title), [
      'Добавить роль',
      'Удалить роль',
    ]);
  });

  testWidgets(
    'creation validates fields and submits only checked server permissions',
    (tester) async {
      await open(tester, CreateRoleDialog(repository: repository));
      await press(tester, find.byKey(const Key('role-create-submit')));
      expect(find.text('Укажите название'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
      await roleFields(tester);
      await press(
        tester,
        find.byKey(const ValueKey('role-permission-customers.read')),
      );
      await press(tester, find.byKey(const Key('role-create-submit')));
      expect(created!.code, 'new_role');
      expect(created!.permissions, ['customers.read']);
      expect(find.byType(CreateRoleDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty selection is explicit and accepted without invented default rights',
    (tester) async {
      api.permissions.clear();
      await open(tester, CreateRoleDialog(repository: repository));
      expect(find.textContaining('Справочник разрешений пуст'), findsOneWidget);
      await roleFields(tester);
      await press(tester, find.byKey(const Key('role-create-submit')));
      expect(created!.permissions, isEmpty);
    },
  );

  testWidgets(
    'permission catalog failure offers retry without losing the route',
    (tester) async {
      api.failures['GET /permissions'] = (403, 'permission_denied');
      await open(tester, CreateRoleDialog(repository: repository));
      expect(find.textContaining('roles.manage'), findsOneWidget);
      expect(find.byKey(const Key('role-create-submit')), findsNothing);
      api.failures.clear();
      await press(tester, find.text('Повторить'));
      expect(find.text('Просмотр клиентов'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lost create response preserves fields and blocks blind repeat', (
    tester,
  ) async {
    api.timeouts.add('POST /roles');
    await open(tester, CreateRoleDialog(repository: repository));
    await roleFields(tester);
    await press(tester, find.byKey(const Key('role-create-submit')));
    expect(find.textContaining('Роль могла уже появиться'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('role-code')))
          .controller!
          .text,
      'new_role',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('role-create-submit')))
          .onPressed,
      isNull,
    );
    expect(api.requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  testWidgets('pending write disables duplicate submit and closing', (
    tester,
  ) async {
    api.writeGate = Completer<void>();
    await open(tester, CreateRoleDialog(repository: repository));
    await roleFields(tester);
    await press(tester, find.byKey(const Key('role-create-submit')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('role-create-submit')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Закрыть',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(api.requests.where((r) => r.method == 'POST'), hasLength(1));
    api.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(created, isNotNull);
  });

  for (final system in [false, true]) {
    testWidgets(
      'delete blocks ${system ? 'system' : 'assigned'} roles after fresh inspection',
      (tester) async {
        api.roles[0] = roleBody(system: system, employees: system ? 0 : 2);
        // DELETE returns bool, so mount directly instead of the typed creation helper.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: DeleteRoleDialog(repository: repository)),
          ),
        );
        await tester.pumpAndSettle();
        await selectRole(tester);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('role-delete-submit')))
              .onPressed,
          isNull,
        );
        expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);
        expect(api.requests.where((r) => r.path == '/roles/9'), hasLength(1));
      },
    );
  }

  testWidgets(
    'concurrent assignment clears stale deletion confirmation and rereads roles',
    (tester) async {
      api.failures['DELETE /roles/9'] = (409, 'role_in_use');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DeleteRoleDialog(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();
      await selectRole(tester);
      api.roles[0]['employee_count'] = 1;
      await press(tester, find.byKey(const Key('role-delete-submit')));
      expect(find.textContaining('включая архивированных'), findsOneWidget);
      expect(find.text('Продолжить'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('role-delete-submit')))
            .onPressed,
        isNull,
      );
      expect(
        api.requests.where((r) => r.path == '/roles' && r.method == 'GET'),
        hasLength(2),
      );
      await selectRole(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('role-delete-submit')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('empty role list has no destructive action', (tester) async {
    api.roles.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DeleteRoleDialog(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Удалять нечего'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('role-delete-submit')))
          .onPressed,
      isNull,
    );
  });

  Future<void> openModule(
    WidgetTester tester, {
    bool employee = false,
    String action = 'create',
  }) async {
    final module = employee
        ? employees.createModule(api.client)
        : roles.createModule(api.client);
    tester.view.physicalSize = const Size(1100, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationListener<ModuleDataChanged>(
            onNotification: (_) {
              changes++;
              return true;
            },
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => module.actions
                    .firstWhere((a) => a.id == action)
                    .onSelected(context),
                child: const Text('Действие'),
              ),
            ),
          ),
        ),
      ),
    );
    await press(tester, find.text('Действие'));
  }

  testWidgets(
    'registered role actions create/delete and notify readers after confirmed success',
    (tester) async {
      await openModule(tester);
      await roleFields(tester);
      await press(tester, find.byKey(const Key('role-create-submit')));
      expect(changes, 1);
      await openModule(tester, action: 'delete');
      await selectRole(tester);
      await press(tester, find.byKey(const Key('role-delete-submit')));
      expect(find.byType(DeleteRoleDialog), findsNothing);
      // The creation snackbar is still ahead of deletion in the SDK queue.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Роль удалена'), findsOneWidget);
      expect(changes, 2);
      expect(api.requests.last.method, 'DELETE');
    },
  );

  testWidgets(
    'employee role action uses the same dialog, selects result and keeps its draft',
    (tester) async {
      await openModule(tester, employee: true);
      await enter(tester, 'employee-name', 'Тестовый Сотрудник');
      await enter(tester, 'employee-login', 'test.user');
      await press(tester, find.byKey(const Key('employee-role')));
      await press(tester, find.text('Создать роль…').last);
      expect(find.byType(CreateRoleDialog), findsOneWidget);
      await roleFields(tester);
      await press(
        tester,
        find.byKey(const ValueKey('role-permission-tasks.read')),
      );
      await press(tester, find.byKey(const Key('role-create-submit')));
      expect(changes, 1);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('employee-name')))
            .controller!
            .text,
        'Тестовый Сотрудник',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('employee-login')))
            .controller!
            .text,
        'test.user',
      );
      await press(tester, find.byKey(const Key('employee-create-submit')));
      expect(
        api.requests.singleWhere((r) => r.path == '/employees').data['role_id'],
        42,
      );
      expect(find.text('Сотрудник создан'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'canceling nested role creation keeps the previous role, never submits the menu action ID',
    (tester) async {
      await openModule(tester, employee: true);
      await enter(tester, 'employee-name', 'Тестовый Сотрудник');
      await enter(tester, 'employee-login', 'test.user');
      await press(tester, find.byKey(const Key('employee-role')));
      await press(tester, find.text('Оператор').last);
      await press(tester, find.byKey(const Key('employee-role')));
      await press(tester, find.text('Создать роль…').last);
      await press(tester, find.text('Отмена').last);
      await press(tester, find.byKey(const Key('employee-create-submit')));
      expect(
        api.requests.singleWhere((r) => r.path == '/employees').data['role_id'],
        9,
      );
      expect(
        api.requests.where((r) => r.path == '/roles' && r.method == 'POST'),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('creation from employee form also works when no roles existed', (
    tester,
  ) async {
    api.roles.clear();
    await openModule(tester, employee: true);
    await enter(tester, 'employee-name', 'Тестовый Сотрудник');
    await enter(tester, 'employee-login', 'test.user');
    await press(tester, find.byKey(const Key('employee-role')));
    await press(tester, find.text('Создать роль…').last);
    await roleFields(tester);
    await press(tester, find.byKey(const Key('role-create-submit')));
    await press(tester, find.byKey(const Key('employee-create-submit')));
    expect(
      api.requests.singleWhere((r) => r.path == '/employees').data['role_id'],
      42,
    );
    expect(tester.takeException(), isNull);
  });
}
