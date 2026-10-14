import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:crm_interface/core/modules/module_registry.dart';
import 'package:crm_interface/core/modules/module_data_changes.dart';
import 'package:crm_interface/layout/app_shell.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/models/profile.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/modules/employees/module.dart' as employees;
import 'package:crm_interface/modules/employees/widgets/create_employee.dart';
import 'package:crm_interface/modules/employees/widgets/archive_employee.dart';
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class EmployeeNavigationAuth extends AuthRepository {
  EmployeeNavigationAuth(super.apiClient, super.sessionStore);
  @override
  Future<AuthProfile> getProfile() async => const AuthProfile(
    id: 1,
    login: 'fixture',
    fullName: 'Тест',
    roleName: 'Роль',
  );
}

void main() {
  late ApiClient api;
  late ModuleDefinition module;
  late ModuleRegistry registry;
  var requests = 0;
  final seen = <RequestOptions>[];
  setUp(() {
    requests = 0;
    seen.clear();
    api = ApiClient(SessionStore());
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          seen.add(options);
          if (options.path == '/roles' || options.path == '/branches') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: options.path == '/roles'
                    ? [
                        {
                          'id': 9,
                          'name': 'Тестовая роль',
                          'description': null,
                          'permissions': <String>[],
                        },
                      ]
                    : <Map<String, dynamic>>[],
              ),
            );
          } else if (options.path == '/employees' && options.method == 'POST') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'employee': {
                    'id': 7,
                    'full_name': 'Тестовый Сотрудник',
                    'login': 'test.user',
                    'is_active': true,
                  },
                  'temporary_password': 'test-only-result',
                },
              ),
            );
          } else if (options.path == '/employees/lookup') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 7,
                  'full_name': 'Тестовый Сотрудник',
                  'login': 'test.user',
                  'role': {'name': 'Роль'},
                  'is_active': true,
                  'version': 12,
                  'open_tasks': 2,
                },
              ),
            );
          } else if (options.path == '/employees/7/deactivate') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'employee': {'id': 7, 'is_active': false, 'version': 13},
                  'unassigned_task_ids': [10, 11],
                },
              ),
            );
          } else {
            handler.reject(DioException(requestOptions: options));
          }
        },
      ),
    );
    module = employees.createModule(api);
    registry = ModuleRegistry([
      ModuleDefinition(
        id: 'first',
        title: 'Первый',
        description: 'Тест',
        icon: Icons.apps,
        screenBuilder: (_) => Column(
          children: [
            Builder(
              builder: (context) =>
                  Text('Revision ${ModuleDataScope.revisionOf(context)}'),
            ),
            const TextField(key: Key('existing-draft')),
          ],
        ),
      ),
      module,
    ]);
  });
  tearDown(() => api.dio.close(force: true));

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          modules: registry,
          authRepository: EmployeeNavigationAuth(api, api.sessionStore),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final more = find.byKey(const Key('sidebar-more-modules'));
  final entry = find.byKey(const ValueKey('overflow-module-employees'));
  Finder action(String id) =>
      find.byKey(ValueKey('module-action-employees-$id'));

  test(
    'action-only manifest is immutable and never selected as initial screen',
    () {
      expect(module.screenBuilder, isNull);
      expect(module.pinnedByDefault, isFalse);
      expect(module.actions.map((action) => action.id), ['create', 'archive']);
      expect(() => module.actions.clear(), throwsUnsupportedError);
      expect(ModuleRegistry([module]).first, isNull);
      expect(
        () => ModuleRegistry([
          ModuleDefinition.menu(
            id: 'bad',
            title: 'Bad',
            description: '',
            icon: Icons.apps,
            actions: [],
          ),
        ]),
        throwsArgumentError,
      );
    },
  );

  testWidgets('submenu loads creation catalogs and preserves screen state', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('existing-draft')), 'Черновик');
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.tap(action('create'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateEmployeeDialog), findsOneWidget);
    expect(find.text('Черновик'), findsOneWidget);
    await tester.tap(find.byKey(const Key('employee-dialog-close')));
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.tap(action('archive'));
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveEmployeeDialog), findsOneWidget);
    expect(find.text('Черновик'), findsOneWidget);
    expect(requests, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'submenu hover crossing does not prematurely close the root menu',
    (tester) async {
      await open(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await tester.tap(more);
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(entry));
      await tester.pumpAndSettle();
      expect(action('create'), findsOneWidget);
      await mouse.moveTo(tester.getCenter(action('archive')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(action('archive'), findsOneWidget);
      await mouse.moveTo(const Offset(750, 550));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(entry, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registered creation loads catalogs, saves through API and invalidates readers without losing draft',
    (tester) async {
      await open(tester);
      await tester.enterText(
        find.byKey(const Key('existing-draft')),
        'Черновик',
      );
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tester.tap(action('create'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('employee-name')),
        'Тестовый Сотрудник',
      );
      await tester.enterText(
        find.byKey(const Key('employee-login')),
        'test.user',
      );
      final role = find.byKey(const Key('employee-role'));
      await tester.ensureVisible(role);
      await tester.tap(role);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Тестовая роль').last);
      await tester.pumpAndSettle();
      final submit = find.byKey(const Key('employee-create-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Сотрудник создан'), findsOneWidget);
      expect(find.text('Черновик'), findsOneWidget);
      expect(find.text('Revision 1'), findsOneWidget);
      expect(
        seen.map((r) => r.path),
        containsAll(['/roles', '/branches', '/employees']),
      );
      expect(
        seen.singleWhere((r) => r.path == '/employees').data['branches'],
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registered deactivation sends the confirmed version and invalidates readers',
    (tester) async {
      await open(tester);
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tester.tap(action('archive'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('employee-archive-login')),
        'test.user',
      );
      await tester.tap(find.byKey(const Key('employee-archive-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Тестовый Сотрудник'), findsOneWidget);
      expect(seen.where((r) => r.method == 'POST'), isEmpty);
      await tester.ensureVisible(
        find.byKey(const Key('employee-archive-submit')),
      );
      await tester.tap(find.byKey(const Key('employee-archive-submit')));
      await tester.pumpAndSettle();
      expect(seen.last.path, '/employees/7/deactivate');
      expect(seen.last.data, {'version': 12});
      expect(find.text('Revision 1'), findsOneWidget);
      expect(find.textContaining('Сотрудник архивирован'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pinned employees keep actions rather than replacing the main screen',
    (tester) async {
      await open(tester);
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.tap(entry, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('module-placement-employees')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sidebar-module-employees')));
      await tester.pumpAndSettle();
      await tester.tap(action('archive'));
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveEmployeeDialog), findsOneWidget);
      expect(find.byKey(const Key('existing-draft')), findsOneWidget);
      expect(requests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keyboard can enter submenu and Escape closes it', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(action('archive'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
