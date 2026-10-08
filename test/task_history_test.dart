import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/tasks/models/task_details.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/repos/request_error.dart';
import 'package:crm_interface/modules/tasks/widgets/task_history.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> detailsJson() => {
  'id': 12,
  'column_id': 9,
  'title': 'Задача',
  'description': null,
  'status': 'new',
  'priority': 'normal',
  'subtasks': [],
  'version': 2,
  'column_history': [
    {
      'previous_column': null,
      'new_column': {'id': 1, 'name': 'Новые'},
      'changed_at': '2026-10-08T08:00:00Z',
      'changed_by': {'id': 4, 'full_name': 'Автор'},
      'reason': null,
    },
    {
      'previous_column': {'id': 1, 'name': 'Новые'},
      'new_column': {'id': 9, 'name': 'Ожидание'},
      'changed_at': '2026-10-08T09:00:00Z',
      'changed_by': {'id': 4, 'full_name': 'Автор'},
      'reason': 'Ждём ответа',
    },
  ],
  'status_history': [
    {
      'previous_status': null,
      'new_status': 'new',
      'changed_at': '2026-10-08T08:00:00Z',
      'changed_by': {'id': 4, 'full_name': 'Автор'},
      'reason': null,
    },
  ],
  'assignment_history': [
    {
      'previous_employee': null,
      'new_employee': {'id': 4, 'full_name': 'Автор'},
      'changed_at': '2026-10-08T08:00:00Z',
      'changed_by': {'id': 4, 'full_name': 'Автор'},
      'reason': null,
    },
  ],
};

class HistoryRepository extends TasksRepository {
  HistoryRepository() : super(ApiClient(SessionStore()));
  bool fail = false;
  bool empty = false;
  @override
  Future<TaskDetails> getTaskDetails(String taskId) async {
    if (fail) throw const TaskRequestException('Недостаточно прав');
    final json = detailsJson();
    if (empty) {
      json['column_history'] = [];
      json['status_history'] = [];
      json['assignment_history'] = [];
    }
    return TaskDetails.fromApi(json);
  }
}

void main() {
  test(
    'GET task details parses nullable column origin and history arrays',
    () async {
      final client = ApiClient(SessionStore());
      addTearDown(() => client.dio.close(force: true));
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.path, '/tasks/12');
            expect(request.method, 'GET');
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: detailsJson(),
              ),
            );
          },
        ),
      );
      final details = await TasksRepository(client).getTaskDetails('12');
      expect(details.columnHistory.first.previousColumn, isNull);
      expect(details.columnHistory.last.newColumn.name, 'Ожидание');
      expect(details.columnHistory.last.reason, 'Ждём ответа');
      expect(details.statusHistory.single.previousStatus, isNull);
      expect(details.assignmentHistory.single.previousEmployee, isNull);
      expect(details.task.status, 'new');
    },
  );

  testWidgets('shows all three histories, reason, and newest movement first', (
    tester,
  ) async {
    final repo = HistoryRepository();
    addTearDown(() => repo.apiClient.dio.close(force: true));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskHistoryWindow(taskId: '12', repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Колонка: Новые → Ожидание'), findsOneWidget);
    expect(find.text('Задача создана в колонке «Новые»'), findsOneWidget);
    expect(find.text('Причина: Ждём ответа'), findsOneWidget);
    expect(find.text('Статус: Не указан → Новая'), findsOneWidget);
    expect(find.text('Ответственный: Не назначен → Автор'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Колонка: Новые → Ожидание')).dy,
      lessThan(
        tester.getTopLeft(find.text('Задача создана в колонке «Новые»')).dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('history error supports retry and empty response', (
    tester,
  ) async {
    final repo = HistoryRepository()..fail = true;
    addTearDown(() => repo.apiClient.dio.close(force: true));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskHistoryWindow(taskId: '12', repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Недостаточно прав'), findsOneWidget);
    repo.fail = false;
    repo.empty = true;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('История задачи пока пуста'), findsOneWidget);
  });
}
