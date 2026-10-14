import 'package:crm_interface/core/api_client/client.dart';
import 'package:dio/dio.dart';

import '../models/employee_forms.dart';

enum _Operation { read, create, deactivate }

class EmployeesRepository {
  const EmployeesRepository(this.apiClient);
  final ApiClient apiClient;

  EmployeeFormFailure _uncertain(_Operation operation) => EmployeeFormFailure(
    operation == _Operation.create
        ? 'Создание не подтверждено. Аккаунт мог быть создан, а временный пароль — не получен. Не повторяйте создание вслепую: проверьте логин и при необходимости сбросьте пароль через администратора.'
        : 'Отключение не подтверждено. Проверьте сотрудника по логину заново перед повторным подтверждением.',
    retryAllowed: operation != _Operation.create,
    refreshRequired: operation == _Operation.deactivate,
  );

  EmployeeFormFailure _failure(DioException error, _Operation operation) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final detail = data is Map ? data['detail'] : null;
    final code = detail is Map ? detail['code'] : null;
    if (code == 'version_conflict') {
      return const EmployeeFormFailure(
        'Данные сотрудника изменились. Проверьте логин и подтвердите отключение заново.',
        refreshRequired: true,
      );
    }
    if (status == 401) {
      return const EmployeeFormFailure('Сессия завершена. Войдите снова.');
    }
    if (status == 403 && code == 'permission_denied') {
      return const EmployeeFormFailure(
        'Недостаточно прав. Требуется управление сотрудниками.',
      );
    }
    if (status == 404) {
      return const EmployeeFormFailure(
        'Сотрудник с таким точным логином не найден. Проверьте написание.',
      );
    }
    if (status != null && status >= 400 && status < 500) {
      var message = detail is Map && detail['message'] is String
          ? detail['message'] as String
          : 'Проверьте данные и попробуйте ещё раз.';
      final fields = detail is Map ? detail['errors'] : null;
      if (fields is List) {
        const labels = {
          'full_name': 'ФИО',
          'login': 'Логин',
          'role_id': 'Роль',
          'branches': 'Филиалы',
          'version': 'Версия',
        };
        final explanations = fields.whereType<Map>().take(3).map((field) {
          final name = field['field']?.toString() ?? '';
          return '${labels[name.split('.').first] ?? 'Поле'}: ${field['message'] is String ? field['message'] : 'проверьте значение'}';
        });
        message = [message, ...explanations].join('\n');
      }
      return EmployeeFormFailure(message);
    }
    return operation == _Operation.read
        ? const EmployeeFormFailure(
            'Не удалось загрузить данные сотрудников. Проверьте соединение и повторите запрос.',
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
        throw const FormatException('Unexpected employee status');
      }
      return decode(response.data);
    } on DioException catch (error) {
      throw _failure(error, operation);
    } on FormatException {
      throw operation == _Operation.read
          ? const EmployeeFormFailure(
              'Некорректный ответ сервера. Обновите данные.',
            )
          : _uncertain(operation);
    } on TypeError {
      throw operation == _Operation.read
          ? const EmployeeFormFailure(
              'Некорректный ответ сервера. Обновите данные.',
            )
          : _uncertain(operation);
    }
  }

  Future<List<EmployeeRoleChoice>> getRoles() => _request(
    () => apiClient.dio.get<dynamic>('/roles'),
    (data) => List.unmodifiable(
      (data as List).map((value) {
        final role = Map<String, dynamic>.from(value as Map);
        final permissions = List<String>.from(role['permissions'] as List);
        return EmployeeRoleChoice(
          id: role['id'] as int,
          name: role['name'] as String,
          description:
              role['description'] as String? ??
              'Разрешений в роли: ${permissions.length}. Доступ проверяется сервером.',
        );
      }),
    ),
  );

  Future<List<EmployeeBranchChoice>> getBranches() => _request(
    () => apiClient.dio.get<dynamic>('/branches'),
    (data) => List.unmodifiable(
      (data as List)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .where((branch) => branch['is_active'] as bool)
          .map(
            (branch) => EmployeeBranchChoice(
              id: branch['id'] as int,
              name: branch['name'] as String,
            ),
          ),
    ),
  );

  Future<EmployeeFormOptions> getFormOptions() async {
    // Both requests have handlers immediately, including when either fails.
    final values = await Future.wait<Object>([getRoles(), getBranches()]);
    return EmployeeFormOptions(
      roles: values[0] as List<EmployeeRoleChoice>,
      branches: values[1] as List<EmployeeBranchChoice>,
    );
  }

  Future<EmployeeCreatedView> create(EmployeeCreateDraft draft) => _request(
    () => apiClient.dio.post<dynamic>(
      '/employees',
      data: {
        'full_name': draft.fullName.trim(),
        'login': draft.login.trim().toLowerCase(),
        'role_id': draft.roleId,
        'branches': [
          for (final id in draft.branchIds)
            {'branch_id': id, 'is_primary': id == draft.primaryBranchId},
        ],
      },
    ),
    (data) {
      final body = Map<String, dynamic>.from(data as Map);
      final employee = Map<String, dynamic>.from(body['employee'] as Map);
      final secret = body['temporary_password'] as String;
      if (secret.isEmpty ||
          employee['is_active'] != true ||
          (employee['id'] as int) < 1 ||
          employee['login'] != draft.login.trim().toLowerCase()) {
        throw const FormatException('Invalid creation result');
      }
      return EmployeeCreatedView(
        fullName: employee['full_name'] as String,
        login: employee['login'] as String,
        temporaryPassword: secret,
      );
    },
    status: 201,
    operation: _Operation.create,
  );

  Future<EmployeeArchiveView> findByLogin(String login) => _request(
    () => apiClient.dio.get<dynamic>(
      '/employees/lookup',
      queryParameters: {'login': login.trim().toLowerCase()},
    ),
    (data) {
      final body = Map<String, dynamic>.from(data as Map);
      final role = Map<String, dynamic>.from(body['role'] as Map);
      final result = EmployeeArchiveView(
        id: body['id'] as int,
        fullName: body['full_name'] as String,
        login: body['login'] as String,
        roleName: role['name'] as String,
        openTasks: body['open_tasks'] as int,
        version: body['version'] as int,
        isActive: body['is_active'] as bool,
      );
      if (result.login.toLowerCase() != login.trim().toLowerCase() ||
          result.id < 1 ||
          result.version < 1 ||
          result.openTasks < 0) {
        throw const FormatException('Invalid lookup result');
      }
      return result;
    },
  );

  Future<void> deactivate(EmployeeArchiveView employee) => _request<void>(
    () => apiClient.dio.post<dynamic>(
      '/employees/${employee.id}/deactivate',
      data: {'version': employee.version},
    ),
    (data) {
      final body = Map<String, dynamic>.from(data as Map);
      final current = Map<String, dynamic>.from(body['employee'] as Map);
      List<int>.from(body['unassigned_task_ids'] as List);
      if (current['id'] != employee.id ||
          current['is_active'] != false ||
          (current['version'] as int) < employee.version) {
        throw const FormatException('Deactivation not confirmed');
      }
    },
    operation: _Operation.deactivate,
  );
}
