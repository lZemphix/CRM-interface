import 'dart:async';

import 'package:appflowy_board/appflowy_board.dart';
import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_data_changes.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:crm_interface/modules/tasks/repos/request_error.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/screens/tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/board_sync.dart';
import 'package:crm_interface/modules/tasks/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TaskboardColumn column(String id, {String? name}) => TaskboardColumn(
  id: id,
  name: name ?? 'Колонка $id',
  order: int.parse(id),
  countsAsDone: false,
  status: null,
  version: 1,
);

TaskboardTask task({
  String id = '10',
  String columnId = '1',
  String title = 'Первая задача',
  int version = 1,
  bool done = false,
  String? responsibleName,
}) => TaskboardTask(
  id: id,
  columnId: columnId,
  title: title,
  description: null,
  priority: 'normal',
  version: version,
  responsibleEmployeeName: responsibleName,
  subtasks: [
    TaskboardTaskSubtask(id: 1, title: 'Проверить', done: done, order: 0),
  ],
);

class RefreshRepository extends TasksRepository {
  RefreshRepository() : super(ApiClient(SessionStore()));

  Taskboard board = Taskboard(
    columns: [column('1'), column('2')],
    tasks: [task()],
  );
  int reads = 0;
  bool failRead = false;
  bool failMove = false;
  Completer<Taskboard>? nextRead;
  Completer<TaskboardTask>? subtaskSave;

  @override
  Future<Taskboard> getTaskBoard() async {
    reads++;
    final pending = nextRead;
    nextRead = null;
    if (pending != null) return pending.future;
    if (failRead) throw const TaskRequestException('Сервер недоступен');
    return board;
  }

  @override
  Future<TaskboardTask> markSubtask(
    String taskId,
    int subtaskId,
    MarkSubtaskRequest request,
  ) async => subtaskSave!.future;

  @override
  Future<TaskboardTask> moveTask(String taskId, MoveTaskRequest request) async {
    if (failMove) throw const TaskRequestException('Конфликт версии');
    return task(columnId: request.columnId.toString(), version: 2);
  }
}

Future<void> openBoard(
  WidgetTester tester,
  RefreshRepository repo, {
  ValueNotifier<int>? revision,
}) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => repo.apiClient.dio.close(force: true));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: revision == null
            ? TasksScreen(tasksRepository: repo)
            : ModuleDataScope(
                revision: revision,
                child: TasksScreen(tasksRepository: repo),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AppFlowyBoardController controller(WidgetTester tester) =>
    tester.widget<AppFlowyBoard>(find.byType(AppFlowyBoard)).controller;

TaskboardTask displayedTask(WidgetTester tester) =>
    tester.widget<TaskCard>(find.byType(TaskCard).first).task;

ScrollableState columnScroll(WidgetTester tester, String taskId) => tester
    .stateList<ScrollableState>(
      find.ancestor(
        of: find.byKey(ValueKey(taskId)),
        matching: find.byType(Scrollable),
      ),
    )
    .singleWhere(
      (state) =>
          axisDirectionToAxis(state.widget.axisDirection) == Axis.vertical,
    );

void main() {
  testWidgets(
    'retained hidden board pauses polling and rejects old GET before refreshing on return',
    (tester) async {
      final repo = RefreshRepository();
      addTearDown(() => repo.apiClient.dio.close(force: true));
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final index = ValueNotifier(0);
      final revision = ValueNotifier(0);
      addTearDown(index.dispose);
      addTearDown(revision.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModuleDataScope(
              revision: revision,
              child: ValueListenableBuilder<int>(
                valueListenable: index,
                builder: (_, value, _) => IndexedStack(
                  index: value,
                  children: [
                    TasksScreen(tasksRepository: repo),
                    const Center(child: Text('Другой модуль')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final original = controller(tester);
      final state = tester.state(find.byType(TasksScreen));
      await tester.tap(find.text('Подзадачи · 0/1'));
      await tester.pumpAndSettle();
      final pending = Completer<Taskboard>();
      repo.nextRead = pending;
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      expect(repo.reads, 2);
      index.value = 1;
      await tester.pump();
      pending.complete(
        Taskboard(
          columns: repo.board.columns,
          tasks: [task(title: 'Старый GET')],
        ),
      );
      await tester.pumpAndSettle();
      revision.value++;
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(repo.reads, 2);
      expect(state.mounted, isTrue);
      repo.board = Taskboard(
        columns: repo.board.columns,
        tasks: [task(title: 'Актуальная задача', version: 2)],
      );
      final fresh = Completer<Taskboard>();
      repo.nextRead = fresh;
      index.value = 0;
      await tester.pump();
      expect(controller(tester), same(original));
      expect(displayedTask(tester).title, 'Первая задача');
      expect(find.byType(CircularProgressIndicator), findsNothing);
      fresh.complete(repo.board);
      await tester.pumpAndSettle();
      expect(repo.reads, 3);
      expect(displayedTask(tester).title, 'Актуальная задача');
      expect(find.text('Проверить').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('identical snapshots produce no controller notifications', () {
    final c = AppFlowyBoardController();
    addTearDown(c.dispose);
    expect(
      synchronizeTaskBoard(
        c,
        Taskboard(columns: [column('1')], tasks: [task()]),
      ),
      isTrue,
    );
    var notifications = 0;
    c.addListener(() => notifications++);
    c.getGroupController('1')!.addListener(() => notifications++);
    expect(
      synchronizeTaskBoard(
        c,
        Taskboard(columns: [column('1')], tasks: [task()]),
      ),
      isFalse,
    );
    expect(notifications, 0);
    expect(sameTaskBoardColumns([column('1')], [column('1')]), isTrue);
    expect(
      sameTaskBoardColumns([column('1')], [column('1', name: 'Изменена')]),
      isFalse,
    );
  });

  testWidgets(
    'module mutation invalidates an old GET and rereads board without losing controller',
    (tester) async {
      final repo = RefreshRepository();
      final revision = ValueNotifier(0);
      addTearDown(revision.dispose);
      repo.board = Taskboard(
        columns: [column('1')],
        tasks: [task(responsibleName: 'Бывший исполнитель')],
      );
      await openBoard(tester, repo, revision: revision);
      final original = controller(tester);
      final stale = Completer<Taskboard>();
      repo.nextRead = stale;
      await tester.tap(find.text('Обновить'));
      await tester.pump();
      repo.board = Taskboard(columns: [column('1')], tasks: [task(version: 2)]);
      revision.value++;
      await tester.pump();
      stale.complete(
        Taskboard(
          columns: [column('1')],
          tasks: [task(responsibleName: 'Бывший исполнитель')],
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.reads, 3);
      expect(controller(tester), same(original));
      expect(displayedTask(tester).responsibleEmployeeName, isNull);
      expect(displayedTask(tester).version, 2);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'snapshot reconciles columns, order, moves, removals and nested names',
    () {
      final c = AppFlowyBoardController();
      addTearDown(c.dispose);
      synchronizeTaskBoard(
        c,
        Taskboard(
          columns: [column('1'), column('2'), column('3')],
          tasks: [
            task(),
            task(id: '11'),
            task(id: '12', columnId: '3'),
          ],
        ),
      );
      final keptGroup = c.getGroupController('1');
      final keptCard = keptGroup!.items.first;
      synchronizeTaskBoard(
        c,
        Taskboard(
          columns: [
            column('2', name: 'Переименована'),
            column('1'),
            column('4'),
          ],
          tasks: [
            task(id: '11', columnId: '2'),
            task(),
            task(id: '13', columnId: '4'),
          ],
        ),
      );
      expect(c.groupIds, ['2', '1', '4']);
      expect(c.getGroupController('1'), same(keptGroup));
      expect(c.getGroupController('1')!.items.single, same(keptCard));
      expect(
        c.getGroupController('2')!.groupData.headerData.groupName,
        'Переименована',
      );
      expect(c.getGroupController('2')!.items.single.id, '11');
      expect(c.getGroupController('4')!.items.single.id, '13');
      synchronizeTaskBoard(
        c,
        Taskboard(
          columns: [column('1')],
          tasks: [task(responsibleName: 'Новое имя')],
        ),
      );
      final updated =
          c.getGroupController('1')!.items.single as TasksCanbanCard;
      expect(updated.task.responsibleEmployeeName, 'Новое имя');
      expect(updated, isNot(same(keptCard)));
    },
  );

  testWidgets('polls every 20 seconds and manual refresh updates immediately', (
    tester,
  ) async {
    final repo = RefreshRepository();
    await openBoard(tester, repo);
    await tester.pump(const Duration(seconds: 19));
    expect(repo.reads, 1);
    repo.board = Taskboard(
      columns: repo.board.columns,
      tasks: [task(title: 'Обновлена', version: 2)],
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(repo.reads, 2);
    expect(displayedTask(tester).title, 'Обновлена');
    repo.board = Taskboard(
      columns: repo.board.columns,
      tasks: [task(title: 'С кнопки', version: 3)],
    );
    await tester.tap(find.text('Обновить'));
    await tester.pumpAndSettle();
    expect(repo.reads, 3);
    expect(displayedTask(tester).title, 'С кнопки');
  });

  testWidgets(
    'unchanged polls preserve card, column, scroll and expanded checklist',
    (tester) async {
      final repo = RefreshRepository();
      repo.board = Taskboard(
        columns: [for (var i = 1; i <= 8; i++) column('$i')],
        tasks: [task()],
      );
      await openBoard(tester, repo);
      final c = controller(tester);
      final group = c.getGroupController('1');
      final card = group!.items.single;
      await tester.tap(find.text('Подзадачи · 0/1'));
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<AppFlowyBoard>(find.byType(AppFlowyBoard))
          .scrollController!;
      scroll.jumpTo(90);
      await tester.pump();
      // A fresh DTO instance with identical values must not replace the card.
      repo.board = Taskboard(columns: repo.board.columns, tasks: [task()]);
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(c.getGroupController('1'), same(group));
      expect(group.items.single, same(card));
      expect(scroll.offset, 90);
      expect(find.text('Проверить').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('slow polling does not overlap or allow another manual GET', (
    tester,
  ) async {
    final repo = RefreshRepository();
    await openBoard(tester, repo);
    final pending = Completer<Taskboard>();
    repo.nextRead = pending;
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(repo.reads, 2);
    expect(find.text('Обновление…'), findsOneWidget);
    await tester.tap(find.text('Обновление…'));
    await tester.pump(const Duration(seconds: 40));
    expect(repo.reads, 2);
    pending.complete(repo.board);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(repo.reads, 3);
  });

  testWidgets(
    'unchanged automatic and manual GETs retain the vertical reading position',
    (tester) async {
      final repo = RefreshRepository();
      repo.board = Taskboard(
        columns: [column('1'), column('2')],
        tasks: [for (var i = 100; i < 120; i++) task(id: '$i')],
      );
      await openBoard(tester, repo);
      final boardView = tester.widget<AppFlowyBoard>(
        find.byType(AppFlowyBoard),
      );
      final scroll = columnScroll(tester, '100');
      scroll.position.jumpTo(450);
      await tester.pumpAndSettle();
      final pending = Completer<Taskboard>();
      repo.nextRead = pending;
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      expect(columnScroll(tester, '100').position.pixels, 450);
      expect(
        tester.widget<AppFlowyBoard>(find.byType(AppFlowyBoard)),
        same(boardView),
      );
      pending.complete(
        Taskboard(
          columns: [column('1'), column('2')],
          tasks: [for (var i = 100; i < 120; i++) task(id: '$i')],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Обновить'));
      await tester.pumpAndSettle();
      expect(columnScroll(tester, '100'), same(scroll));
      expect(scroll.position.pixels, 450);
      expect(
        tester.widget<AppFlowyBoard>(find.byType(AppFlowyBoard)),
        same(boardView),
      );
      repo.failRead = true;
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Данные могут быть устаревшими'),
        findsOneWidget,
      );
      expect(columnScroll(tester, '100'), same(scroll));
      expect(scroll.position.pixels, 450);
      repo.failRead = false;
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Данные могут быть устаревшими'),
        findsNothing,
      );
      expect(columnScroll(tester, '100'), same(scroll));
      expect(scroll.position.pixels, 450);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real changes update cards without resetting vertical scroll or open checklists',
    (tester) async {
      final repo = RefreshRepository();
      repo.board = Taskboard(
        columns: [column('1'), column('2')],
        tasks: [
          for (var i = 100; i < 120; i++) task(id: '$i'),
          for (var i = 200; i < 216; i++) task(id: '$i', columnId: '2'),
        ],
      );
      await openBoard(tester, repo);
      final checklist = find.descendant(
        of: find.byKey(const ValueKey('100')),
        matching: find.text('Подзадачи · 0/1'),
      );
      await tester.tap(checklist);
      await tester.pumpAndSettle();
      final scroll = columnScroll(tester, '100');
      scroll.position.jumpTo(450);
      columnScroll(tester, '200').position.jumpTo(180);
      await tester.pumpAndSettle();
      repo.board = Taskboard(
        columns: [column('1'), column('2')],
        tasks: [
          for (var i = 100; i < 120; i++)
            task(
              id: '$i',
              title: i == 100 ? 'Изменена другим сотрудником' : 'Первая задача',
              version: i == 100 ? 2 : 1,
            ),
          task(id: '120'),
          task(id: '121', columnId: '2'),
          for (var i = 200; i < 216; i++) task(id: '$i', columnId: '2'),
        ],
      );
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(columnScroll(tester, '100'), same(scroll));
      expect(scroll.position.pixels, 450);
      expect(find.text('Изменена другим сотрудником'), findsOneWidget);
      expect(find.byKey(const ValueKey('120')), findsOneWidget);
      expect(find.byKey(const ValueKey('121')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('100')),
          matching: find.text('Проверить'),
        ),
        findsOneWidget,
      );
      repo.board = Taskboard(
        columns: [
          column('2'),
          column('1', name: 'Новое название'),
          column('3'),
        ],
        tasks: repo.board.tasks,
      );
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(find.text('Новое название'), findsOneWidget);
      expect(controller(tester).groupIds, ['2', '1', '3']);
      expect(columnScroll(tester, '100').position.pixels, 450);
      expect(columnScroll(tester, '200').position.pixels, 180);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('100')),
          matching: find.text('Проверить'),
        ),
        findsOneWidget,
      );
      repo.board = Taskboard(
        columns: repo.board.columns,
        tasks: [
          task(id: '100', title: 'Осталась одна'),
          task(id: '200', columnId: '2'),
        ],
      );
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(columnScroll(tester, '100').position.pixels, 0);
      expect(columnScroll(tester, '200').position.pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('background error keeps data, avoids snackbars and recovers', (
    tester,
  ) async {
    final repo = RefreshRepository();
    await openBoard(tester, repo);
    repo.failRead = true;
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(displayedTask(tester).title, 'Первая задача');
    expect(
      find.textContaining('Данные могут быть устаревшими'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    repo.failRead = false;
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(find.textContaining('Данные могут быть устаревшими'), findsNothing);
  });

  testWidgets(
    'initial error can be retried and empty board allows first column',
    (tester) async {
      final repo = RefreshRepository()..failRead = true;
      await openBoard(tester, repo);
      expect(
        find.text('Доска не загружена. Нажмите «Обновить».'),
        findsOneWidget,
      );
      repo.failRead = false;
      repo.board = const Taskboard(columns: [], tasks: []);
      await tester.tap(find.text('Обновить'));
      await tester.pumpAndSettle();
      expect(
        find.text('Нет колонок. Добавьте первую колонку.'),
        findsOneWidget,
      );
      await tester.tap(find.text('+ Колонка'));
      await tester.pumpAndSettle();
      final reads = repo.reads;
      await tester.pump(const Duration(seconds: 40));
      expect(repo.reads, reads);
    },
  );

  testWidgets(
    'holding a pointer pauses polls and invalidates an in-flight GET',
    (tester) async {
      final repo = RefreshRepository();
      await openBoard(tester, repo);
      final old = Completer<Taskboard>();
      repo.nextRead = old;
      await tester.pump(const Duration(seconds: 20));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Первая задача')),
      );
      old.complete(
        Taskboard(
          columns: repo.board.columns,
          tasks: [task(title: 'Устаревшая')],
        ),
      );
      await tester.pump();
      expect(displayedTask(tester).title, 'Первая задача');
      await tester.pump(const Duration(seconds: 20));
      expect(repo.reads, 2);
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(repo.reads, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late snapshot cannot undo a saved subtask; no poll during save',
    (tester) async {
      final repo = RefreshRepository();
      await openBoard(tester, repo);
      await tester.tap(find.text('Подзадачи · 0/1'));
      await tester.pumpAndSettle();
      final old = Completer<Taskboard>();
      repo.nextRead = old;
      await tester.pump(const Duration(seconds: 20));
      repo.subtaskSave = Completer<TaskboardTask>();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      expect(repo.reads, 2);
      repo.subtaskSave!.complete(task(version: 2, done: true));
      await tester.pumpAndSettle();
      old.complete(repo.board);
      await tester.pumpAndSettle();
      expect(displayedTask(tester).version, 2);
      expect(displayedTask(tester).subtasks.single.done, isTrue);
    },
  );

  testWidgets('move recovery waits for stale GET then reads a fresh snapshot', (
    tester,
  ) async {
    final repo = RefreshRepository()..failMove = true;
    await openBoard(tester, repo);
    final old = Completer<Taskboard>();
    repo.nextRead = old;
    await tester.pump(const Duration(seconds: 20));
    final c = controller(tester);
    final item = c.getGroupController('1')!.items.single;
    c.removeGroupItem('1', item.id);
    c.addGroupItem('2', item);
    c.onMoveGroupItemToGroup!('1', 0, '2', 0);
    await tester.pump();
    expect(repo.reads, 2);
    old.complete(repo.board);
    await tester.pumpAndSettle();
    expect(repo.reads, 3);
    expect(displayedTask(tester).columnId, '1');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pauses in background, refreshes on resume and stops on dispose',
    (tester) async {
      final repo = RefreshRepository();
      await openBoard(tester, repo);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 40));
      expect(repo.reads, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.reads, 2);
      final old = Completer<Taskboard>();
      repo.nextRead = old;
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpWidget(const SizedBox());
      old.complete(repo.board);
      await tester.pump(const Duration(seconds: 60));
      expect(repo.reads, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
