import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:dio/dio.dart';

Map<String, dynamic> roleBody({
  int id = 9,
  bool system = false,
  int employees = 0,
}) => {
  'id': id,
  'code': 'operator',
  'name': 'Оператор',
  'description': null,
  'is_system': system,
  'employee_count': employees,
  'version': 1,
  'permissions': ['customers.read'],
};

/// Test-only HTTP fixture. Nothing is installed into the application.
class RolesTestApi {
  RolesTestApi() {
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          final key = '${options.method} ${options.path}';
          if (options.method != 'GET' && writeGate != null) {
            await writeGate!.future;
          }
          if (timeouts.contains(key)) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              ),
            );
            return;
          }
          final error = failures[key];
          if (error != null) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: error.$1,
                  data: {
                    'detail': {
                      'code': error.$2,
                      'message': 'Сообщение сервера',
                    },
                  },
                ),
              ),
            );
            return;
          }
          dynamic data;
          var status = 200;
          if (overrides.containsKey(key)) {
            data = overrides[key];
            status = statuses[key] ?? 200;
          } else if (options.path == '/permissions') {
            data = permissions;
          } else if (options.path == '/roles' && options.method == 'GET') {
            data = roles
                .map((role) => Map<String, dynamic>.from(role))
                .toList();
          } else if (options.path == '/roles' && options.method == 'POST') {
            final input = Map<String, dynamic>.from(options.data as Map);
            data = {...roleBody(id: 42), ...input};
            roles.add(data as Map<String, dynamic>);
            status = 201;
          } else if (options.path.startsWith('/roles/')) {
            final id = int.parse(options.path.split('/').last);
            final role = roles.where((value) => value['id'] == id).firstOrNull;
            if (role == null) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: options,
                    statusCode: 404,
                    data: {
                      'detail': {'code': 'role_not_found'},
                    },
                  ),
                ),
              );
              return;
            }
            if (options.method == 'DELETE') {
              roles.remove(role);
              status = 204;
            } else {
              data = Map<String, dynamic>.from(role);
            }
          } else if (options.path == '/branches') {
            data = <Map<String, dynamic>>[];
          } else if (options.path == '/employees' && options.method == 'POST') {
            data = {
              'employee': {
                'id': 5,
                'full_name': 'Тестовый Сотрудник',
                'login': 'test.user',
                'is_active': true,
              },
              'temporary_password': 'test-only-result',
            };
            status = 201;
          } else {
            handler.reject(DioException(requestOptions: options));
            return;
          }
          handler.resolve(
            Response(requestOptions: options, statusCode: status, data: data),
          );
        },
      ),
    );
  }
  final client = ApiClient(SessionStore());
  final requests = <RequestOptions>[];
  final roles = <Map<String, dynamic>>[roleBody()];
  final permissions = <Map<String, dynamic>>[
    {
      'code': 'customers.read',
      'name': 'Просмотр клиентов',
      'description': 'Разрешает читать карточки клиентов.',
    },
    {'code': 'tasks.read', 'name': 'Просмотр задач', 'description': null},
  ];
  final failures = <String, (int, String)>{};
  final timeouts = <String>{};
  final overrides = <String, dynamic>{};
  final statuses = <String, int>{};
  Completer<void>? writeGate;
  void close() => client.dio.close(force: true);
}
