import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/repos/request_error.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/customer_next_task.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_interface/core/widgets/section_refresh_controller.dart';

import 'support/section_refresh.dart';

TaskboardTask task({
  String id = '12',
  String status = 'in_progress',
  DateTime? day,
  int? employeeId,
}) => TaskboardTask(
  id: id,
  columnId: '1',
  title: 'Задача $id',
  description: null,
  priority: 'normal',
  status: status,
  customerId: 7,
  responsibleEmployeeId: employeeId,
  responsibleEmployeeName: 'Тестовый сотрудник',
  dueDate: day,
  subtasks: [],
  version: 1,
);

class FakeRepository extends TasksRepository {
  FakeRepository() : super(ApiClient(SessionStore())) {
    addTearDown(refresh.dispose);
  }
  final refresh = SectionRefreshController();
  TaskboardTask? next;
  final ids = <int>[];
  final completed = <String>[];
  final started = <String>[];
  Future<void>? startDelay;
  bool failStart = false;
  bool fail = false;
  bool failComplete = false;
  Future<TaskboardTask?> Function(int)? loader;

  @override
  Future<TaskboardTask?> getClosestCustomerTask(int customerId) async {
    ids.add(customerId);
    if (loader != null) return loader!(customerId);
    if (fail) throw const TaskRequestException('Нет доступа к задачам');
    return next;
  }

  @override
  Future<TaskboardTask> completeTask(String taskId) async {
    completed.add(taskId);
    if (failComplete) {
      throw const TaskRequestException('Завершать может только исполнитель');
    }
    next = task(id: '13', status: 'new');
    return task(status: 'completed');
  }

  @override
  Future<TaskboardTask> startTask(String taskId) async {
    started.add(taskId);
    if (startDelay != null) await startDelay;
    if (failStart) {
      throw const TaskRequestException(
        'В работу может перевести только исполнитель',
      );
    }
    next = task(id: taskId, employeeId: 4);
    return next!;
  }
}

Widget panel(
  FakeRepository repo, {
  int customerId = 7,
  int token = 0,
  VoidCallback? changed,
}) => MaterialApp(
  home: Scaffold(
    appBar: AppBar(actions: [sectionRefreshButton(repo.refresh)]),
    body: CustomerNextTask(
      refreshController: repo.refresh,
      customerId: customerId,
      repository: repo,
      reloadToken: token,
      onChanged: changed,
    ),
  ),
);

Map<String, dynamic> jsonTask(int id, String status, {int customerId = 7}) => {
  'id': id,
  'column_id': 1,
  'title': 'Задача $id',
  'description': null,
  'priority': 'normal',
  'status': status,
  'customer': {'id': customerId, 'full_name': 'Тестовый клиент'},
  'subtasks': [],
  'version': 1,
};

void main() {
  for (final status in ['new', 'rework']) {
    testWidgets('assignment offers start, then completion for $status', (
      tester,
    ) async {
      final repo = FakeRepository()..next = task(status: status);
      addTearDown(() => repo.apiClient.dio.close(force: true));
      var changes = 0;
      await tester.pumpWidget(panel(repo, changed: () => changes++));
      await tester.pumpAndSettle();
      expect(find.text('В работу'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );

      // Like assignment in the task board: status does not change automatically.
      repo.next = task(status: status, employeeId: 4);
      await tester.tap(find.byTooltip('Обновить вкладку'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      final pending = Completer<void>();
      repo.startDelay = pending.future;
      await tester.tap(find.text('В работу'));
      await tester.pump();
      expect(find.text('Сохранение'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(repo.started, ['12']);
      expect(repo.completed, isEmpty);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('В работе'), findsOneWidget);
      expect(find.text('Выполнено'), findsOneWidget);
      expect(changes, 1);
      await tester.tap(find.text('Выполнено'));
      await tester.pumpAndSettle();
      expect(repo.completed, ['12']);
      expect(changes, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('start permission rejection preserves status and allows retry', (
    tester,
  ) async {
    final repo = FakeRepository()
      ..next = task(status: 'new', employeeId: 4)
      ..failStart = true;
    addTearDown(() => repo.apiClient.dio.close(force: true));
    var changes = 0;
    await tester.pumpWidget(panel(repo, changed: () => changes++));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В работу'));
    await tester.pumpAndSettle();
    expect(find.text('Новая'), findsOneWidget);
    expect(
      find.text('В работу может перевести только исполнитель'),
      findsOneWidget,
    );
    expect(changes, 0);
    expect(repo.completed, isEmpty);
    repo.failStart = false;
    await tester.tap(find.text('В работу'));
    await tester.pumpAndSettle();
    expect(find.text('В работе'), findsOneWidget);
    expect(changes, 1);
  });

  test('start POST sends in_progress, not completed or assignment', () async {
    final client = ApiClient(SessionStore());
    addTearDown(() => client.dio.close(force: true));
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (request, handler) {
          expect(request.method, 'POST');
          expect(request.path, '/tasks/12/status');
          expect(request.data, {'status': 'in_progress'});
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: jsonTask(12, 'in_progress'),
            ),
          );
        },
      ),
    );
    expect(
      (await TasksRepository(client).startTask('12')).status,
      'in_progress',
    );
  });

  testWidgets('empty state has no completion button', (tester) async {
    final repo = FakeRepository();
    addTearDown(() => repo.apiClient.dio.close(force: true));
    await tester.pumpWidget(panel(repo));
    await tester.pumpAndSettle();
    expect(find.text('У клиента нет незавершённых задач'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('Выполнено'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'task details and completion load the next task and notify list',
    (tester) async {
      final repo = FakeRepository()..next = task(day: DateTime(2026, 10, 9));
      addTearDown(() => repo.apiClient.dio.close(force: true));
      var changes = 0;
      await tester.pumpWidget(panel(repo, changed: () => changes++));
      await tester.pumpAndSettle();
      expect(find.text('Задача 12'), findsOneWidget);
      expect(
        find.text('Срок до: 09.10.2026 • Тестовый сотрудник'),
        findsOneWidget,
      );
      await tester.tap(find.text('Выполнено'));
      await tester.pumpAndSettle();
      expect(repo.completed, ['12']);
      expect(changes, 1);
      expect(find.text('Задача 13'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(find.text('Без срока • Тестовый сотрудник'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('server rejection leaves task unchanged and shows error', (
    tester,
  ) async {
    final repo = FakeRepository()
      ..next = task()
      ..failComplete = true;
    addTearDown(() => repo.apiClient.dio.close(force: true));
    await tester.pumpWidget(panel(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выполнено'));
    await tester.pumpAndSettle();
    expect(find.text('Задача 12'), findsOneWidget);
    expect(find.text('Завершать может только исполнитель'), findsOneWidget);
    expect(repo.ids, [7]);
  });

  testWidgets('loading failure is not empty state and can be retried', (
    tester,
  ) async {
    final repo = FakeRepository()..fail = true;
    addTearDown(() => repo.apiClient.dio.close(force: true));
    await tester.pumpWidget(panel(repo));
    await tester.pumpAndSettle();
    expect(find.text('Нет доступа к задачам'), findsOneWidget);
    expect(find.text('У клиента нет незавершённых задач'), findsNothing);
    repo.fail = false;
    repo.next = task(status: 'rework');
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('На доработке'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets(
    'old customer response cannot overwrite a new customer; reload refreshes',
    (tester) async {
      final old = Completer<TaskboardTask?>();
      final repo = FakeRepository()
        ..loader = (id) async => id == 7 ? old.future : task(id: '22');
      addTearDown(() => repo.apiClient.dio.close(force: true));
      await tester.pumpWidget(panel(repo));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pumpWidget(panel(repo, customerId: 8));
      await tester.pumpAndSettle();
      old.complete(task());
      await tester.pumpAndSettle();
      expect(find.text('Задача 22'), findsOneWidget);
      expect(find.text('Задача 12'), findsNothing);
      await tester.pumpWidget(panel(repo, customerId: 8, token: 1));
      await tester.pumpAndSettle();
      expect(repo.ids, [7, 8, 8]);
      await tester.tap(find.byTooltip('Обновить вкладку'));
      await tester.pumpAndSettle();
      expect(repo.ids.last, 8);
      expect(tester.takeException(), isNull);
    },
  );

  test('repository skips completed pages, uses server deadline sorting and preserves nulls', () async {
    final client = ApiClient(SessionStore());
    addTearDown(() => client.dio.close(force: true));
    final offsets = <int>[];
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (request, handler) {
          expect(request.path, '/tasks');
          expect(request.queryParameters['customer_id'], 7);
          expect(request.queryParameters['sort'], 'due_at');
          final offset = request.queryParameters['offset'] as int;
          offsets.add(offset);
          final items = offset == 0
              ? List.generate(20, (id) => jsonTask(id, 'completed'))
              : [
                  jsonTask(21, 'confirmed'),
                  jsonTask(22, 'cancelled'),
                  jsonTask(23, 'new'),
                ];
          handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'items': items,
                'total': 23,
                'limit': 20,
                'offset': offset,
              },
            ),
          );
        },
      ),
    );
    final closest = await TasksRepository(client).getClosestCustomerTask(7);
    expect(offsets, [0, 20]);
    expect(closest!.id, '23');
    expect(closest.dueAt, isNull);
    expect(closest.dueDate, isNull);
  });

  test('repository returns null for empty or completed-only lists', () async {
    final client = ApiClient(SessionStore());
    addTearDown(() => client.dio.close(force: true));
    var completedOnly = false;
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'items': completedOnly ? [jsonTask(1, 'completed')] : [],
                'total': completedOnly ? 1 : 0,
                'limit': 20,
                'offset': 0,
              },
            ),
          );
        },
      ),
    );
    final repo = TasksRepository(client);
    expect(await repo.getClosestCustomerTask(7), isNull);
    completedOnly = true;
    expect(await repo.getClosestCustomerTask(7), isNull);
  });

  testWidgets('late response after disposal does not update state', (
    tester,
  ) async {
    final pending = Completer<TaskboardTask?>();
    final repo = FakeRepository()..loader = (_) => pending.future;
    addTearDown(() => repo.apiClient.dio.close(force: true));
    await tester.pumpWidget(panel(repo));
    await tester.pumpWidget(const SizedBox());
    pending.complete(task());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test(
    'completion POST uses real status endpoint and reads updated server task',
    () async {
      final client = ApiClient(SessionStore());
      addTearDown(() => client.dio.close(force: true));
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.path, '/tasks/12/status');
            expect(request.method, 'POST');
            expect(request.data, {'status': 'completed'});
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: jsonTask(12, 'completed'),
              ),
            );
          },
        ),
      );
      final updated = await TasksRepository(client).completeTask('12');
      expect(updated.status, 'completed');
    },
  );
}
