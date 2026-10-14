import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/employees/models/employee_forms.dart';
import 'package:crm_interface/modules/employees/repos/employees_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> lookupBody({
  bool active = true,
  String login = 'test.user',
}) => {
  'id': 7,
  'full_name': 'Тестовый Сотрудник',
  'login': login,
  'role': {'id': 9, 'code': 'fixture', 'name': 'Тестовая роль'},
  'is_active': active,
  'version': 12,
  'open_tasks': 2,
};
Map<String, dynamic> createdBody() => {
  'employee': lookupBody(),
  'temporary_password': 'test-only-result',
};
Map<String, dynamic> deactivatedBody() => {
  'employee': {...lookupBody(active: false), 'version': 13},
  'unassigned_task_ids': [10, 11],
};

void main() {
  late ApiClient api;
  late EmployeesRepository repo;
  final requests = <RequestOptions>[];
  dynamic body;
  int status = 200;
  String? code;
  bool timeout = false;
  setUp(() {
    requests.clear();
    status = 200;
    code = null;
    timeout = false;
    body = null;
    api = ApiClient(SessionStore());
    repo = EmployeesRepository(api);
    api.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (timeout) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              ),
            );
            return;
          }
          if (status >= 400) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: status,
                  data:
                      body ??
                      {
                        'detail': {
                          'code': code,
                          'message': 'Сообщение сервера',
                        },
                      },
                ),
              ),
            );
          } else {
            handler.resolve(
              Response(requestOptions: options, statusCode: status, data: body),
            );
          }
        },
      ),
    );
  });
  tearDown(() => api.dio.close(force: true));
  final draft = EmployeeCreateDraft(
    fullName: ' Тестовый Сотрудник ',
    login: ' TEST.USER ',
    roleId: 9,
    branchIds: [1, 2],
    primaryBranchId: 2,
  );
  const preview = EmployeeArchiveView(
    id: 7,
    fullName: 'Тест',
    login: 'test.user',
    roleName: 'Роль',
    openTasks: 2,
    version: 12,
  );

  test(
    'role and branch catalogs are typed, inactive branches are not selectable',
    () async {
      body = [
        {
          'id': 9,
          'name': 'Роль',
          'description': null,
          'permissions': ['tasks.read'],
        },
      ];
      final roles = await repo.getRoles();
      expect(roles.single.id, 9);
      expect(roles.single.description, contains('1'));
      expect(() => roles.clear(), throwsUnsupportedError);
      body = [
        {'id': 1, 'name': 'Первый', 'is_active': true},
        {'id': 2, 'name': 'Второй', 'is_active': false},
      ];
      final branches = await repo.getBranches();
      expect(branches.single.name, 'Первый');
      expect(requests.map((r) => r.path), ['/roles', '/branches']);
    },
  );

  test(
    'creation sends JSON with branch assignment flags, never a password',
    () async {
      status = 201;
      body = createdBody();
      final result = await repo.create(draft);
      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/employees');
      expect(requests.single.data, {
        'full_name': 'Тестовый Сотрудник',
        'login': 'test.user',
        'role_id': 9,
        'branches': [
          {'branch_id': 1, 'is_primary': false},
          {'branch_id': 2, 'is_primary': true},
        ],
      });
      expect(result.temporaryPassword, 'test-only-result');
      expect(result.login, 'test.user');
    },
  );

  test('creation without branches sends an empty list', () async {
    status = 201;
    body = createdBody();
    await repo.create(
      EmployeeCreateDraft(
        fullName: 'Тест',
        login: 'test.user',
        roleId: 9,
        branchIds: [],
      ),
    );
    expect(requests.single.data['branches'], isEmpty);
  });

  test(
    'lookup is an exact normalized query, with active state and version',
    () async {
      body = lookupBody();
      final result = await repo.findByLogin(' TEST.USER ');
      expect(requests.single.path, '/employees/lookup');
      expect(requests.single.queryParameters, {'login': 'test.user'});
      expect(result.id, 7);
      expect(result.version, 12);
      expect(result.openTasks, 2);
      expect(result.isActive, isTrue);
      body = lookupBody(active: false);
      expect((await repo.findByLogin('test.user')).isActive, isFalse);
    },
  );

  test(
    'a mismatched lookup must not allow confirmation of another account',
    () async {
      body = lookupBody(login: 'someone.else');
      await expectLater(
        repo.findByLogin('test.user'),
        throwsA(isA<EmployeeFormFailure>()),
      );
    },
  );

  test('deactivation uses its dedicated POST with the confirmed version, not PATCH', () async {
    body = deactivatedBody();
    await repo.deactivate(preview);
    expect(requests.single.path, '/employees/7/deactivate');
    expect(requests.single.method, 'POST');
    expect(requests.single.data, {'version': 12});
  });

  test('permission, self/last-admin guards and duplicate login retain API messages', () async {
    for (final entry in [
      (403, 'permission_denied'),
      (403, 'employee_escalation_denied'),
      (409, 'self_modification_forbidden'),
      (409, 'last_administrator'),
      (409, 'duplicate_employee_login'),
    ]) {
      status = entry.$1;
      code = entry.$2;
      await expectLater(
        repo.deactivate(preview),
        throwsA(
          isA<EmployeeFormFailure>()
              .having((e) => e.refreshRequired, 'refresh', isFalse)
              .having((e) => e.message, 'message', isNotEmpty),
        ),
      );
    }
  });

  test('version conflict requires a fresh lookup and confirmation', () async {
    status = 409;
    code = 'version_conflict';
    await expectLater(
      repo.deactivate(preview),
      throwsA(
        isA<EmployeeFormFailure>()
            .having((e) => e.refreshRequired, 'refresh', isTrue)
            .having((e) => e.retryAllowed, 'retry', isTrue),
      ),
    );
  });

  test(
    'validation details are readable without echoing a raw response',
    () async {
      status = 422;
      body = {
        'detail': {
          'code': 'validation_error',
          'message': 'Проверьте данные',
          'errors': [
            {'field': 'login', 'message': 'Неверный формат'},
          ],
        },
      };
      await expectLater(
        repo.create(draft),
        throwsA(
          isA<EmployeeFormFailure>().having(
            (e) => e.message,
            'message',
            contains('Логин: Неверный формат'),
          ),
        ),
      );
    },
  );

  test('unknown creation outcome blocks repeats; deactivation allows only a fresh confirmation', () async {
    timeout = true;
    await expectLater(
      repo.create(draft),
      throwsA(
        isA<EmployeeFormFailure>().having(
          (e) => e.retryAllowed,
          'retry',
          isFalse,
        ),
      ),
    );
    await expectLater(
      repo.deactivate(preview),
      throwsA(
        isA<EmployeeFormFailure>().having(
          (e) => e.refreshRequired,
          'refresh',
          isTrue,
        ),
      ),
    );
    await expectLater(
      repo.findByLogin('test.user'),
      throwsA(
        isA<EmployeeFormFailure>().having(
          (e) => e.retryAllowed,
          'retry',
          isTrue,
        ),
      ),
    );
  });

  test('malformed write replies never produce a false success', () async {
    status = 201;
    body = {'employee': lookupBody()};
    await expectLater(
      repo.create(draft),
      throwsA(
        isA<EmployeeFormFailure>().having(
          (e) => e.retryAllowed,
          'retry',
          isFalse,
        ),
      ),
    );
    status = 200;
    body = {'employee': lookupBody(), 'unassigned_task_ids': []};
    await expectLater(
      repo.deactivate(preview),
      throwsA(
        isA<EmployeeFormFailure>().having(
          (e) => e.refreshRequired,
          'refresh',
          isTrue,
        ),
      ),
    );
  });
}
