import 'package:crm_interface/modules/roles/models/role.dart';
import 'package:crm_interface/modules/roles/repos/roles_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/roles_api.dart';

void main() {
  late RolesTestApi api;
  late RolesRepository repository;
  setUp(() {
    api = RolesTestApi();
    repository = RolesRepository(api.client);
  });
  tearDown(() => api.close());

  CreateRoleRequest draft({
    Iterable<String> permissions = const ['customers.read'],
  }) => CreateRoleRequest(
    code: ' NEW_ROLE ',
    name: ' Новая роль ',
    description: ' ',
    permissions: permissions,
  );

  test(
    'permission catalog and roles are typed, nullable and immutable',
    () async {
      final permissions = await repository.getPermissions();
      expect(permissions.first.description, contains('карточки'));
      expect(permissions.last.description, isNull);
      expect(() => permissions.clear(), throwsUnsupportedError);
      final roles = await repository.getRoles();
      expect(roles.single.canDelete, isTrue);
      expect(roles.single.description, isNull);
      expect(() => roles.single.permissions.clear(), throwsUnsupportedError);
      expect(() => roles.clear(), throwsUnsupportedError);
    },
  );

  test(
    'create posts normalized explicit JSON and returns a complete role',
    () async {
      final role = await repository.create(draft());
      expect(role.id, 42);
      expect(role.permissions, ['customers.read']);
      expect(api.requests.single.method, 'POST');
      expect(api.requests.single.path, '/roles');
      expect(api.requests.single.data, {
        'code': 'new_role',
        'name': 'Новая роль',
        'description': null,
        'permissions': ['customers.read'],
      });
      expect(api.requests.single.queryParameters, isEmpty);
    },
  );

  test('roles without permissions are allowed by the API contract', () async {
    final role = await repository.create(draft(permissions: []));
    expect(role.permissions, isEmpty);
    expect(api.requests.single.data['permissions'], isEmpty);
  });

  test(
    'get exact role and DELETE 204 use no unsupported version/body',
    () async {
      final role = await repository.getRole(9);
      expect(role.code, 'operator');
      await repository.delete(role.id);
      expect(api.requests.last.method, 'DELETE');
      expect(api.requests.last.path, '/roles/9');
      expect(api.requests.last.data, isNull);
      expect(api.roles, isEmpty);
    },
  );

  for (final entry in <String, (int, String)>{
    'permission_denied': (403, 'roles.manage'),
    'role_escalation_denied': (403, 'правами'),
    'duplicate_role_code': (409, 'код'),
    'unknown_permission': (422, 'Сообщение сервера'),
  }.entries) {
    test('create reports ${entry.key} without clearing the draft', () async {
      api.failures['POST /roles'] = (entry.value.$1, entry.key);
      await expectLater(
        repository.create(draft()),
        throwsA(
          isA<RoleRequestFailure>()
              .having(
                (error) => error.message,
                'message',
                contains(entry.value.$2),
              )
              .having((error) => error.retryAllowed, 'retry', isTrue),
        ),
      );
    });
  }

  for (final code in [
    'role_in_use',
    'system_role_read_only',
    'role_not_found',
  ]) {
    test('delete $code requires a fresh role selection', () async {
      api.failures['DELETE /roles/9'] = (
        code == 'role_not_found' ? 404 : 409,
        code,
      );
      await expectLater(
        repository.delete(9),
        throwsA(
          isA<RoleRequestFailure>().having(
            (error) => error.refreshRequired,
            'refresh',
            isTrue,
          ),
        ),
      );
    });
  }

  test('401 asks to sign in, never fabricates success', () async {
    api.failures['GET /permissions'] = (401, 'invalid_credentials');
    await expectLater(
      repository.getPermissions(),
      throwsA(
        isA<RoleRequestFailure>().having(
          (error) => error.message,
          'message',
          contains('Войдите'),
        ),
      ),
    );
  });

  test(
    'uncertain create blocks retry, uncertain delete requires reread',
    () async {
      api.timeouts.addAll(['POST /roles', 'DELETE /roles/9']);
      await expectLater(
        repository.create(draft()),
        throwsA(
          isA<RoleRequestFailure>().having(
            (error) => error.retryAllowed,
            'retry',
            isFalse,
          ),
        ),
      );
      await expectLater(
        repository.delete(9),
        throwsA(
          isA<RoleRequestFailure>().having(
            (error) => error.refreshRequired,
            'refresh',
            isTrue,
          ),
        ),
      );
      expect(api.requests, hasLength(2));
    },
  );

  test(
    'malformed reads and wrong identity cannot be used for confirmation',
    () async {
      api.overrides['GET /permissions'] = {'items': []};
      await expectLater(
        repository.getPermissions(),
        throwsA(isA<RoleRequestFailure>()),
      );
      api.overrides['GET /roles/9'] = roleBody(id: 99);
      await expectLater(
        repository.getRole(9),
        throwsA(isA<RoleRequestFailure>()),
      );
    },
  );

  test('malformed mutation responses are uncertain, not successful', () async {
    api.overrides['POST /roles'] = roleBody();
    api.statuses['POST /roles'] = 201;
    await expectLater(
      repository.create(draft()),
      throwsA(
        isA<RoleRequestFailure>().having(
          (error) => error.retryAllowed,
          'retry',
          isFalse,
        ),
      ),
    );
    api.overrides['DELETE /roles/9'] = {}; // 200 is not the DELETE contract.
    await expectLater(
      repository.delete(9),
      throwsA(
        isA<RoleRequestFailure>().having(
          (error) => error.refreshRequired,
          'refresh',
          isTrue,
        ),
      ),
    );
  });
}
