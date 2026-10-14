import 'package:crm_interface/core/api_client/client.dart';
import 'package:dio/dio.dart';

import '../models/role.dart';

enum _Operation { read, create, delete }

class RolesRepository {
  const RolesRepository(this.apiClient);
  final ApiClient apiClient;

  RoleRequestFailure _uncertain(_Operation operation) => RoleRequestFailure(
    operation == _Operation.create
        ? 'Создание не подтверждено. Роль могла уже появиться. Не повторяйте запрос вслепую: закройте форму и проверьте список ролей по коду.'
        : 'Удаление не подтверждено. Список будет перечитан; проверьте роль перед новым подтверждением.',
    retryAllowed: operation != _Operation.create,
    refreshRequired: operation == _Operation.delete,
  );

  RoleRequestFailure _failure(DioException error, _Operation operation) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final detail = data is Map ? data['detail'] : null;
    final code = detail is Map ? detail['code'] : null;
    const messages = {
      'permission_denied':
          'Недостаточно прав. Требуется управление ролями (roles.manage).',
      'role_escalation_denied':
          'Нельзя выдать или удалить роль с правами, которых нет у вас.',
      'system_role_read_only': 'Системную роль удалить нельзя.',
      'role_in_use': 'Роль назначена сотрудникам, включая архивированных. Сначала смените им роль.',
      'duplicate_role_code': 'Этот код роли уже занят. Укажите другой.',
      'role_not_found': 'Роль больше не существует. Перечитайте список.',
    };
    if (status == 401) {
      return const RoleRequestFailure('Сессия завершена. Войдите снова.');
    }
    if (status != null && status >= 400 && status < 500) {
      final message =
          messages[code] ??
          (detail is Map && detail['message'] is String
              ? detail['message'] as String
              : 'Проверьте данные роли и попробуйте снова.');
      return RoleRequestFailure(
        message,
        refreshRequired:
            code == 'role_not_found' ||
            (operation == _Operation.delete &&
                (status == 404 || status == 409)),
      );
    }
    return operation == _Operation.read
        ? const RoleRequestFailure(
            'Не удалось загрузить роли или права. Проверьте соединение и повторите запрос.',
          )
        : _uncertain(operation);
  }

  Future<T> _request<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic) decode, {
    int status = 200,
    _Operation operation = _Operation.read,
  }) async {
    try {
      final response = await request();
      if (response.statusCode != status) {
        throw const FormatException('Unexpected role status');
      }
      return decode(response.data);
    } on DioException catch (error) {
      throw _failure(error, operation);
    } on FormatException {
      throw operation == _Operation.read
          ? const RoleRequestFailure(
              'Некорректный ответ сервера. Перечитайте данные ролей.',
            )
          : _uncertain(operation);
    } on TypeError {
      throw operation == _Operation.read
          ? const RoleRequestFailure(
              'Некорректный ответ сервера. Перечитайте данные ролей.',
            )
          : _uncertain(operation);
    }
  }

  Future<List<RolePermission>> getPermissions() => _request(
    () => apiClient.dio.get<dynamic>('/permissions'),
    (data) => List.unmodifiable(
      (data as List).map(
        (item) =>
            RolePermission.fromApi(Map<String, dynamic>.from(item as Map)),
      ),
    ),
  );

  Future<List<RoleInfo>> getRoles() => _request(
    () => apiClient.dio.get<dynamic>('/roles'),
    (data) => List.unmodifiable(
      (data as List).map(
        (item) => RoleInfo.fromApi(Map<String, dynamic>.from(item as Map)),
      ),
    ),
  );

  Future<RoleInfo> getRole(int id) =>
      _request(() => apiClient.dio.get<dynamic>('/roles/$id'), (data) {
        final role = RoleInfo.fromApi(Map<String, dynamic>.from(data as Map));
        if (role.id != id) throw const FormatException('Wrong role');
        return role;
      });

  Future<RoleInfo> create(CreateRoleRequest request) => _request(
    () => apiClient.dio.post<dynamic>('/roles', data: request.toApi()),
    (data) {
      final role = RoleInfo.fromApi(Map<String, dynamic>.from(data as Map));
      if (role.code != request.code.trim().toLowerCase() ||
          role.isSystem ||
          role.permissions
              .toSet()
              .difference(request.permissions.toSet())
              .isNotEmpty ||
          request.permissions
              .toSet()
              .difference(role.permissions.toSet())
              .isNotEmpty) {
        throw const FormatException('Creation not confirmed');
      }
      return role;
    },
    status: 201,
    operation: _Operation.create,
  );

  Future<void> delete(int id) => _request<void>(
    () => apiClient.dio.delete<dynamic>('/roles/$id'),
    (_) {},
    status: 204,
    operation: _Operation.delete,
  );
}
