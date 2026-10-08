import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:crm_interface/modules/tasks/models/task_column.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_interface/modules/tasks/repos/request_error.dart';

void main() {
  test('task edit PATCH sends only requested fields with version', () async {
    final client = ApiClient(SessionStore());
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.method, 'PATCH');
          expect(options.path, '/tasks/12');
          expect(options.data, {
            'title': 'Название',
            'description': 'Описание',
            'priority': 'high',
            'version': 4,
          });
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'id': 12,
                'column_id': 1,
                'title': 'Название',
                'description': 'Описание',
                'priority': 'high',
                'version': 5,
                'subtasks': [],
              },
            ),
          );
        },
      ),
    );
    final updated = await TasksRepository(client).editTask(
      '12',
      const EditTaskRequest(
        title: 'Название',
        description: 'Описание',
        priority: Priority.high,
        version: 4,
      ),
    );
    expect(updated.title, 'Название');
    expect(updated.version, 5);
  });

  for (final employeeId in <int?>[4, null]) {
    test('task assignment POST supports employee_id=$employeeId', () async {
      final client = ApiClient(SessionStore());
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'POST');
            expect(options.path, '/tasks/12/assign');
            expect(options.data, {
              'employee_id': employeeId,
              'reason': 'Переназначение',
            });
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 12,
                  'column_id': 1,
                  'title': 'Название',
                  'description': null,
                  'priority': 'normal',
                  'version': 5,
                  'subtasks': [],
                  'responsible_employee_id': employeeId,
                },
              ),
            );
          },
        ),
      );
      final updated = await TasksRepository(client).assignTask(
        '12',
        AssignTaskRequest(employeeId: employeeId, reason: 'Переназначение'),
      );
      expect(updated.responsibleEmployeeId, employeeId);
    });
  }

  test(
    'subtask PATCH sends done and task version and reads whole updated task',
    () async {
      final client = ApiClient(SessionStore());
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'PATCH');
            expect(options.path, '/tasks/12/subtasks/21');
            expect(options.data, {'done': true, 'version': 4});
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 12,
                  'column_id': 1,
                  'title': 'Задача',
                  'description': null,
                  'priority': 'normal',
                  'version': 5,
                  'subtasks': [
                    {'id': 21, 'title': 'Первый шаг', 'done': true, 'order': 0},
                  ],
                },
              ),
            );
          },
        ),
      );
      final task = await TasksRepository(
        client,
      ).markSubtask('12', 21, const MarkSubtaskRequest(done: true, version: 4));
      expect(task.id, '12');
      expect(task.version, 5);
      expect(task.subtasks.single.done, isTrue);
    },
  );

  test('rename sends PATCH name and version and parses the response', () async {
    final client = ApiClient(SessionStore());
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.method, 'PATCH');
          expect(options.path, '/task-columns/5');
          expect(options.data, {'name': 'Новое имя', 'version': 3});
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'id': 5,
                'name': 'Новое имя',
                'order': 4,
                'status': 'new',
                'counts_as_done': false,
                'version': 4,
              },
            ),
          );
        },
      ),
    );
    final column = await TasksRepository(client).renameColumn(
      '5',
      const RenameTaskColumnRequest(name: 'Новое имя', version: 3),
    );
    expect(column.name, 'Новое имя');
    expect(column.version, 4);
  });

  test(
    'archive sends DELETE with a numeric transfer query and accepts 204',
    () async {
      final client = ApiClient(SessionStore());
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'DELETE');
            expect(options.path, '/task-columns/5');
            expect(options.queryParameters, {'move_to_column_id': 6});
            expect(options.data, isNull);
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 204),
            );
          },
        ),
      );
      await TasksRepository(client).archiveColumn('5', moveToColumnId: '6');
    },
  );

  test('rename preserves the safe version conflict message', () async {
    final client = ApiClient(SessionStore());
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 409,
                data: {
                  'detail': {
                    'message': 'Колонка уже изменена другим сотрудником',
                  },
                },
              ),
            ),
          );
        },
      ),
    );
    await expectLater(
      TasksRepository(client).renameColumn(
        '5',
        const RenameTaskColumnRequest(name: 'Имя', version: 1),
      ),
      throwsA(
        isA<TaskRequestException>().having(
          (error) => error.message,
          'message',
          'Колонка уже изменена другим сотрудником',
        ),
      ),
    );
  });

  test(
    'POST /task-columns sends a DTO and returns the server column',
    () async {
      final client = ApiClient(SessionStore());
      Map<String, dynamic>? sentData;
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/task-columns');
            expect(options.method, 'POST');
            sentData = Map<String, dynamic>.from(options.data as Map);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'id': 5,
                  'name': 'Нормализованное сервером имя',
                  'order': 4,
                  'counts_as_done': false,
                  'status': null,
                  'version': 1,
                },
              ),
            );
          },
        ),
      );
      final column = await TasksRepository(client)
          .createColumn(const CreateTaskColumnRequest(name: 'Моя колонка'));
      expect(sentData, {'name': 'Моя колонка', 'status': null});
      expect(column.id, '5');
      expect(column.name, 'Нормализованное сервером имя');
      expect(column.order, 4);
      expect(column.status, isNull);
      expect(column.version, 1);
    },
  );

  test('column creation propagates a server rejection', () async {
    final client = ApiClient(SessionStore());
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 403,
              data: {
                'detail': {'code': 'forbidden', 'message': 'Недостаточно прав'},
              },
            ),
          ),
        ),
      ),
    );
    await expectLater(
      TasksRepository(client)
          .createColumn(const CreateTaskColumnRequest(name: 'Колонка')),
      throwsA(
        isA<TaskRequestException>().having(
          (error) => error.message,
          'message',
          'Недостаточно прав',
        ),
      ),
    );
  });

  test('column creation rejects an empty response', () async {
    final client = ApiClient(SessionStore());
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 201,
          ),
        ),
      ),
    );
    await expectLater(
      TasksRepository(client)
          .createColumn(const CreateTaskColumnRequest(name: 'Колонка')),
      throwsFormatException,
    );
  });

  test(
    'POST /tasks sends the request DTO and parses the created task',
    () async {
      final client = ApiClient(SessionStore());
      Map<String, dynamic>? sentData;

      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path != '/tasks') return handler.next(options);
            sentData = Map<String, dynamic>.from(options.data as Map);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'id': 42,
                  'column_id': 1,
                  'title': 'Новая задача',
                  'description': null,
                  'priority': 'normal',
                  'responsible_employee_id': null,
                  'responsible': null,
                  'due_at': null,
                  'customer': {'id': 7, 'full_name': 'Клиент'},
                  'branch_id': null,
                  'subtasks': <dynamic>[],
                  'version': 1,
                },
              ),
            );
          },
        ),
      );

      final created = await TasksRepository(client).createTask(
        const CreateTaskRequest(
          columnId: 1,
          title: 'Новая задача',
          priority: Priority.normal,
          responsibleEmployeeId: null,
          subtasks: [Subtask(title: 'Первый шаг')],
        ),
      );

      expect(sentData?['column_id'], 1);
      expect(sentData?['priority'], 'normal');
      expect(sentData?['subtasks'], [
        {'title': 'Первый шаг'},
      ]);
      expect(created.id, '42');
      expect(created.title, 'Новая задача');
      expect(created.description, isNull);
      expect(created.customerId, 7);
    },
  );

  test(
    'GET /task-board parses nested parties and missing description',
    () async {
      final client = ApiClient(SessionStore());
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'columns': [
                    {
                      'id': 1,
                      'name': 'Очередь',
                      'order': 0,
                      'status': 'new',
                      'counts_as_done': false,
                      'version': 2,
                    },
                  ],
                  'tasks': [
                    {
                      'id': 42,
                      'column_id': 1,
                      'title': 'Проверить API',
                      'priority': 'normal',
                      'responsible_employee_id': 4,
                      'responsible': {'id': 4, 'full_name': 'Сотрудник'},
                      'customer': {'id': 7, 'full_name': 'Клиент'},
                      'due_at': '2026-10-10T15:00:00Z',
                      'branch_id': null,
                      'subtasks': <dynamic>[],
                      'version': 3,
                    },
                  ],
                  'truncated': true,
                },
              ),
            );
          },
        ),
      );

      final board = await TasksRepository(client).getTaskBoard();
      expect(board.truncated, isTrue);
      expect(board.columns.single.status, 'new');
      expect(board.columns.single.version, 2);
      expect(board.tasks.single.description, isNull);
      expect(board.tasks.single.customerId, 7);
      expect(board.tasks.single.responsibleEmployeeName, 'Сотрудник');
      expect(board.tasks.single.dueAt, DateTime.utc(2026, 10, 10, 15));
    },
  );

  test('GET /task-board accepts an empty board', () async {
    final client = ApiClient(SessionStore());
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'columns': <dynamic>[],
                'tasks': <dynamic>[],
                'truncated': false,
              },
            ),
          );
        },
      ),
    );
    final board = await TasksRepository(client).getTaskBoard();
    expect(board.columns, isEmpty);
    expect(board.tasks, isEmpty);
    expect(board.truncated, isFalse);
  });
}
