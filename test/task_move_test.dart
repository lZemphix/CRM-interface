import 'dart:async';

import 'package:appflowy_board/appflowy_board.dart';
import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:crm_interface/modules/tasks/repos/request_error.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/screens/tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/customer_next_task.dart';
import 'package:crm_interface/modules/tasks/widgets/task_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const columns = [
  TaskboardColumn(
    id: '1',
    name: 'Новые',
    order: 0,
    countsAsDone: false,
    status: 'new',
    version: 1,
  ),
  TaskboardColumn(
    id: '2',
    name: 'В работе',
    order: 1,
    countsAsDone: false,
    status: 'in_progress',
    version: 1,
  ),
  TaskboardColumn(
    id: '3',
    name: 'Доработка',
    order: 2,
    countsAsDone: false,
    status: 'rework',
    version: 1,
  ),
  TaskboardColumn(
    id: '4',
    name: 'Выполнены',
    order: 3,
    countsAsDone: false,
    status: 'completed',
    version: 1,
  ),
  TaskboardColumn(
    id: '5',
    name: 'Ожидание',
    order: 4,
    countsAsDone: false,
    status: null,
    version: 1,
  ),
];

TaskboardTask task({
  String columnId = '1',
  String status = 'new',
  int version = 4,
}) => TaskboardTask(
  id: '12',
  columnId: columnId,
  title: 'Задача клиента',
  description: null,
  priority: 'normal',
  responsibleEmployeeId: 4,
  customerId: 7,
  status: status,
  subtasks: [],
  version: version,
);

class MoveRepository extends TasksRepository {
  MoveRepository() : super(ApiClient(SessionStore()));
  TaskboardTask saved = task();
  final moves = <MoveTaskRequest>[];
  final movedIds = <String>[];
  int reads = 0;
  bool fail = false;
  bool failRefresh = false;
  Future<void>? pending;

  @override
  Future<Taskboard> getTaskBoard() async {
    reads++;
    if (reads > 1 && failRefresh) {
      throw const TaskRequestException('Не удалось обновить доску');
    }
    return Taskboard(columns: columns, tasks: [saved]);
  }

  @override
  Future<TaskPage> getCustomerTasks(
    int customerId, {
    int limit = 20,
    int offset = 0,
    String sort = 'due_at',
  }) async => TaskPage(items: [saved], total: 1, limit: limit, offset: offset);

  @override
  Future<TaskboardTask> moveTask(String taskId, MoveTaskRequest request) async {
    movedIds.add(taskId);
    moves.add(request);
    if (pending != null) await pending;
    if (fail) {
      throw const TaskRequestException('Переход статуса запрещён');
    }
    final target = columns.singleWhere(
      (item) => int.parse(item.id) == request.columnId,
    );
    saved = task(
      columnId: target.id,
      status: target.status ?? saved.status ?? 'new',
      version: saved.version + 1,
    );
    return saved;
  }
}

Future<void> openBoard(WidgetTester tester, MoveRepository repository) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => repository.apiClient.dio.close(force: true));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TasksScreen(tasksRepository: repository)),
    ),
  );
  await tester.pumpAndSettle();
}

// Simulate the documented post-drop callback using public controller methods.
// AppFlowy has already moved the original DTO when this callback fires.
void drop(WidgetTester tester, String fromId, String toId) {
  final controller = tester
      .widget<AppFlowyBoard>(find.byType(AppFlowyBoard))
      .controller;
  final source = controller.getGroupController(fromId)!;
  final item = source.items.whereType<TasksCanbanCard>().single;
  final fromIndex = source.items.indexOf(item);
  controller.removeGroupItem(fromId, item.id);
  controller.addGroupItem(toId, item);
  final toIndex = controller.getGroupController(toId)!.items.indexOf(item);
  controller.onMoveGroupItemToGroup!(fromId, fromIndex, toId, toIndex);
}

void expectCard(
  WidgetTester tester,
  String columnId,
  String status,
  int version,
) {
  final card = tester.widget<TaskCard>(find.byType(TaskCard));
  expect(card.task.columnId, columnId);
  expect(card.task.status, status);
  expect(card.task.version, version);
  final controller = tester
      .widget<AppFlowyBoard>(find.byType(AppFlowyBoard))
      .controller;
  expect(
    controller
        .getGroupController(columnId)!
        .items
        .whereType<TasksCanbanCard>()
        .length,
    1,
  );
  expect(
    controller.groupDatas
        .expand((group) => group.items)
        .whereType<TasksCanbanCard>()
        .length,
    1,
  );
}

void main() {
  testWidgets(
    'neutral move preserves status/version and does not ask for reason',
    (tester) async {
      final repo = MoveRepository()
        ..saved = task(columnId: '3', status: 'rework');
      await openBoard(tester, repo);
      drop(tester, '3', '5');
      await tester.pumpAndSettle();
      expect(repo.moves.single.toApi(), {'column_id': 5, 'version': 4});
      expectCard(tester, '5', 'rework', 5);
      expect(find.text('Причина переноса'), findsNothing);
      drop(tester, '5', '2');
      await tester.pumpAndSettle();
      expectCard(tester, '2', 'in_progress', 6);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'move persists DTO/version and customer overview reads the same status',
    (tester) async {
      final repo = MoveRepository();
      final pending = Completer<void>();
      repo.pending = pending.future;
      await openBoard(tester, repo);
      drop(tester, '1', '2');
      await tester.pump();
      expect(
        tester
            .widget<AbsorbPointer>(find.byKey(const Key('tasks-move-guard')))
            .absorbing,
        isTrue,
      );
      expect(repo.movedIds, ['12']);
      expect(repo.moves.single.toApi(), {'column_id': 2, 'version': 4});
      pending.complete();
      await tester.pumpAndSettle();
      expectCard(tester, '2', 'in_progress', 5);
      expect(
        tester
            .widget<AbsorbPointer>(find.byKey(const Key('tasks-move-guard')))
            .absorbing,
        isFalse,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerNextTask(customerId: 7, repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Выполнено'), findsOneWidget);
      expect(find.text('В работе'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'forbidden reverse transition rolls back and re-reads server state',
    (tester) async {
      final repo = MoveRepository()
        ..saved = task(columnId: '2', status: 'in_progress')
        ..fail = true;
      await openBoard(tester, repo);
      drop(tester, '2', '1');
      await tester.pumpAndSettle();
      expect(repo.moves.single.columnId, 1);
      expect(repo.reads, 2);
      expectCard(tester, '2', 'in_progress', 4);
      expect(
        find.text('Перенос не подтверждён: Переход статуса запрещён'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed server refresh still restores pre-drop position', (
    tester,
  ) async {
    final repo = MoveRepository()
      ..fail = true
      ..failRefresh = true;
    await openBoard(tester, repo);
    drop(tester, '1', '2');
    await tester.pumpAndSettle();
    expectCard(tester, '1', 'new', 4);
    expect(
      tester
          .widget<AbsorbPointer>(find.byKey(const Key('tasks-move-guard')))
          .absorbing,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled reason restores card without sending move', (
    tester,
  ) async {
    final repo = MoveRepository();
    await openBoard(tester, repo);
    drop(tester, '1', '3');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Причина переноса'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(repo.moves, isEmpty);
    expectCard(tester, '1', 'new', 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reason is validated and sent with version', (tester) async {
    final repo = MoveRepository()
      ..saved = task(columnId: '4', status: 'completed');
    await openBoard(tester, repo);
    drop(tester, '4', '3');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Перенести'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Укажите причину'), findsOneWidget);
    expect(repo.moves, isEmpty);
    await tester.enterText(find.byType(TextFormField), '  Нужна правка  ');
    await tester.tap(find.text('Перенести'));
    await tester.pumpAndSettle();
    expect(repo.moves.single.toApi(), {
      'column_id': 3,
      'version': 4,
      'reason': 'Нужна правка',
    });
    expectCard(tester, '3', 'rework', 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late move after disposal does not update disposed controller', (
    tester,
  ) async {
    final repo = MoveRepository();
    final pending = Completer<void>();
    repo.pending = pending.future;
    await openBoard(tester, repo);
    drop(tester, '1', '2');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test(
    'move API sends column/version/reason and parses server status',
    () async {
      final client = ApiClient(SessionStore());
      addTearDown(() => client.dio.close(force: true));
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.path, '/tasks/12/move');
            expect(request.method, 'POST');
            expect(request.data, {
              'column_id': 3,
              'version': 4,
              'reason': 'Правка',
            });
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'id': 12,
                  'column_id': 3,
                  'title': 'Задача',
                  'description': null,
                  'status': 'rework',
                  'priority': 'normal',
                  'subtasks': [],
                  'version': 5,
                },
              ),
            );
          },
        ),
      );
      final updated = await TasksRepository(client).moveTask(
        '12',
        const MoveTaskRequest(columnId: 3, version: 4, reason: 'Правка'),
      );
      expect(updated.status, 'rework');
      expect(updated.version, 5);
    },
  );
}
