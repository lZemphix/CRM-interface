import 'dart:io';
import 'dart:ui' as ui;

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:crm_interface/modules/tasks/models/task_column.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/screens/tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/create_task.dart';
import 'package:crm_interface/modules/tasks/widgets/create_column.dart';
import 'package:crm_interface/modules/tasks/widgets/task_card.dart';
import 'package:crm_interface/modules/tasks/widgets/task_column_header.dart';
import 'package:crm_interface/modules/tasks/widgets/task_column_footer.dart';
import 'package:crm_interface/modules/tasks/widgets/column_decoration.dart';
import 'package:appflowy_board/appflowy_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTasksRepository extends TasksRepository {
  FakeTasksRepository() : super(ApiClient(SessionStore()));

  CreateTaskRequest? submitted;
  CreateTaskColumnRequest? submittedColumn;
  int boardRequests = 0;
  RenameTaskColumnRequest? renamed;
  String? archived;
  String? archiveTarget;
  final List<MarkSubtaskRequest> subtaskRequests = [];
  List<TaskboardTask> tasks = [];
  List<TaskboardColumn> columns = const [
    TaskboardColumn(
      id: '2',
      name: 'В работе',
      order: 0,
      countsAsDone: false,
      status: 'in_progress',
      version: 1,
    ),
    TaskboardColumn(
      id: '1',
      name: 'Общая очередь',
      order: 1,
      countsAsDone: false,
      status: 'new',
      version: 1,
    ),
  ];

  @override
  Future<Taskboard> getTaskBoard() async {
    boardRequests++;
    return Taskboard(columns: columns, tasks: tasks);
  }

  @override
  Future<TaskboardTask> markSubtask(
    String taskId,
    int subtaskId,
    MarkSubtaskRequest request,
  ) async {
    subtaskRequests.add(request);
    final task = tasks.singleWhere((item) => item.id == taskId);
    final updated = TaskboardTask(
      id: task.id,
      columnId: task.columnId,
      title: task.title,
      description: task.description,
      priority: task.priority,
      version: task.version + 1,
      subtasks: [
        for (final subtask in task.subtasks)
          TaskboardTaskSubtask(
            id: subtask.id,
            title: subtask.title,
            order: subtask.order,
            done: subtask.id == subtaskId ? request.done : subtask.done,
          ),
      ],
    );
    tasks = [for (final item in tasks) item.id == taskId ? updated : item];
    return updated;
  }

  @override
  Future<TaskboardColumn> renameColumn(
    String id,
    RenameTaskColumnRequest request,
  ) async {
    renamed = request;
    final old = columns.singleWhere((column) => column.id == id);
    final updated = TaskboardColumn(
      id: id,
      name: request.name,
      order: old.order,
      countsAsDone: old.countsAsDone,
      status: old.status,
      version: old.version + 1,
    );
    columns = [
      for (final column in columns) column.id == id ? updated : column,
    ];
    return updated;
  }

  @override
  Future<void> archiveColumn(String id, {String? moveToColumnId}) async {
    archived = id;
    archiveTarget = moveToColumnId;
    tasks = [
      for (final task in tasks)
        if (task.columnId != id)
          task
        else
          TaskboardTask(
            id: task.id,
            columnId: moveToColumnId!,
            title: task.title,
            description: task.description,
            priority: task.priority,
            responsibleEmployeeId: task.responsibleEmployeeId,
            responsibleEmployeeName: task.responsibleEmployeeName,
            dueAt: task.dueAt,
            dueDate: task.dueDate,
            timezone: task.timezone,
            customerId: task.customerId,
            customerName: task.customerName,
            status: task.status,
            branchId: task.branchId,
            subtasks: task.subtasks,
            version: task.version + 1,
          ),
    ];
    columns = columns.where((column) => column.id != id).toList();
  }

  @override
  Future<TaskboardColumn> createColumn(CreateTaskColumnRequest request) async {
    submittedColumn = request;
    return TaskboardColumn(
      id: '5',
      name: request.name,
      order: columns.length,
      countsAsDone: request.status == TaskColumnStatus.confirmed,
      status: request.status?.apiValue,
      version: 1,
    );
  }

  @override
  Future<List<TaskEmployee>> getEmployees() async => const [
    TaskEmployee(id: 4, fullName: 'Администратор'),
  ];

  @override
  Future<TaskboardTask> createTask(CreateTaskRequest task) async {
    submitted = task;
    return TaskboardTask(
      id: '42',
      columnId: task.columnId.toString(),
      title: task.title,
      description: task.description,
      priority: task.priority.name,
      dueAt: task.dueAt,
      subtasks: [
        for (var index = 0; index < task.subtasks.length; index++)
          TaskboardTaskSubtask(
            id: index + 1,
            title: task.subtasks[index].title,
            done: false,
            order: index,
          ),
      ],
      version: 1,
    );
  }
}

void main() {
  testWidgets(
    'archives a populated neutral column into another neutral column',
    (tester) async {
      final repo = FakeTasksRepository();
      repo.columns = const [
        TaskboardColumn(
          id: '9',
          name: 'Свободная',
          order: 0,
          countsAsDone: false,
          status: null,
          version: 1,
        ),
        TaskboardColumn(
          id: '10',
          name: 'Ожидание',
          order: 1,
          countsAsDone: false,
          status: null,
          version: 1,
        ),
      ];
      repo.tasks = const [
        TaskboardTask(
          id: '12',
          columnId: '9',
          title: 'Задача',
          description: null,
          priority: 'normal',
          status: 'in_progress',
          subtasks: [],
          version: 1,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TasksScreen(tasksRepository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<TaskColumnAction>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Архивировать'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Архивировать'));
      await tester.pumpAndSettle();
      expect(repo.archived, '9');
      expect(repo.archiveTarget, '10');
    },
  );

  testWidgets(
    'subtask tick updates progress and uses fresh task version on next tick',
    (tester) async {
      final repository = FakeTasksRepository();
      repository.tasks = [
        const TaskboardTask(
          id: '12',
          columnId: '1',
          title: 'Задача с чеклистом',
          description: null,
          priority: 'normal',
          version: 4,
          subtasks: [
            TaskboardTaskSubtask(
              id: 21,
              title: 'Проверить результат',
              done: false,
              order: 0,
            ),
          ],
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TasksScreen(tasksRepository: repository)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Подзадачи ·'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(repository.subtaskRequests.single.toApi(), {
        'done': true,
        'version': 4,
      });
      expect(find.text('1/1'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(repository.subtaskRequests.last.toApi(), {
        'done': false,
        'version': 5,
      });
      expect(find.text('0/1'), findsOneWidget);
      expect(repository.boardRequests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'template column frames fill available height and scroll with board',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 750);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeTasksRepository();
      repository.columns = [
        ...repository.columns,
        const TaskboardColumn(
          id: '3',
          name: 'Проверка',
          order: 2,
          countsAsDone: false,
          status: 'completed',
          version: 1,
        ),
        const TaskboardColumn(
          id: '4',
          name: 'Готово',
          order: 3,
          countsAsDone: true,
          status: 'confirmed',
          version: 1,
        ),
      ];
      repository.tasks = [
        const TaskboardTask(
          id: '8',
          columnId: '1',
          title: 'Подготовить макет карточки',
          description: 'Сверить оформление с шаблоном CRM.',
          priority: 'high',
          subtasks: [],
          version: 1,
        ),
      ];
      final previewKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: previewKey,
          child: MaterialApp(
            home: Scaffold(body: TasksScreen(tasksRepository: repository)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final frames = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is TaskColumnFrames,
      );
      expect(tester.getSize(frames).height, greaterThan(600));
      final board = tester.widget<AppFlowyBoard>(find.byType(AppFlowyBoard));
      final bottomScrollbar = tester.widget<Scrollbar>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Scrollbar &&
              widget.scrollbarOrientation == ScrollbarOrientation.bottom,
        ),
      );
      expect(bottomScrollbar.controller, same(board.scrollController));
      expect(bottomScrollbar.thumbVisibility, isTrue);
      expect(bottomScrollbar.interactive, isTrue);
      expect(board.scrollController!.hasClients, isTrue);
      board.scrollController!.jumpTo(100);
      await tester.pumpAndSettle();
      expect(board.scrollController!.offset, 100);
      expect(tester.takeException(), isNull);
      board.scrollController!.jumpTo(0);
      await tester.pumpAndSettle();
      // Optional visual artifact, kept outside the repository.
      final previewPath = Platform.environment['CRM_KANBAN_PREVIEW'];
      if (previewPath != null) {
        await tester.runAsync(() async {
          final boundary =
              previewKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(previewPath).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );

  testWidgets('column menu renames on the server and updates its header', (
    tester,
  ) async {
    final repository = FakeTasksRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TasksScreen(tasksRepository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<TaskColumnAction>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переименовать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Новый заголовок');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(repository.renamed?.name, 'Новый заголовок');
    expect(repository.renamed?.version, 1);
    expect(find.text('Новый заголовок'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('archive transfers to a same-status column and reloads board', (
    tester,
  ) async {
    final repository = FakeTasksRepository();
    repository.columns = [
      repository.columns.last,
      const TaskboardColumn(
        id: '5',
        name: 'Другая очередь',
        order: 2,
        countsAsDone: false,
        status: 'new',
        version: 1,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TasksScreen(tasksRepository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<TaskColumnAction>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Архивировать'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Архивировать'));
    await tester.pumpAndSettle();
    expect(repository.archived, '1');
    expect(repository.archiveTarget, '5');
    expect(repository.boardRequests, 2);
    expect(find.text('Общая очередь'), findsNothing);
    expect(find.text('Другая очередь'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('last column of a status cannot be archived', (tester) async {
    final repository = FakeTasksRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TasksScreen(tasksRepository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<TaskColumnAction>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Архивировать'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Архивировать'),
          )
          .onPressed,
      isNull,
    );
    expect(repository.archived, isNull);
    expect(find.textContaining('последняя колонка'), findsOneWidget);
  });

  testWidgets('column footer opens the form for that exact column', (
    tester,
  ) async {
    final repository = FakeTasksRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TasksScreen(tasksRepository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    final board = tester.widget<AppFlowyBoard>(find.byType(AppFlowyBoard));
    expect(board.config.groupBackgroundColor, Colors.transparent);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is TaskColumnFrames,
      ),
      findsOneWidget,
    );
    expect(board.config.groupCornerRadius, 16);
    expect(board.config.stretchGroupHeight, isTrue);
    await tester.tap(
      find.descendant(
        of: find.byType(TaskColumnFooter).last,
        matching: find.text('Новая задача'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CreateTaskWindow>(find.byType(CreateTaskWindow))
          .initialColumnId,
      1,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название *'),
      'Из колонки',
    );
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(repository.submitted!.columnId, 1);
    final header = tester
        .widgetList<TaskColumnHeader>(find.byType(TaskColumnHeader))
        .singleWhere((header) => header.title == 'Общая очередь');
    expect(header.taskCount, 1);
    expect(repository.boardRequests, 1);
  });

  testWidgets('closed column footer is disabled', (tester) async {
    final repository = FakeTasksRepository();
    repository.columns = const [
      TaskboardColumn(
        id: '3',
        name: 'Готово',
        order: 0,
        countsAsDone: true,
        status: 'confirmed',
        version: 1,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TasksScreen(tasksRepository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TaskColumnFooter>(find.byType(TaskColumnFooter)).onCreate,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('loaded cards retain the complete task DTO', (tester) async {
    final repository = FakeTasksRepository();
    const task = TaskboardTask(
      id: '101',
      columnId: '1',
      title: 'Проверить клиента',
      description: 'Описание с сервера',
      priority: 'high',
      responsibleEmployeeId: 4,
      responsibleEmployeeName: 'Анна Петрова',
      subtasks: [],
      version: 1,
    );
    repository.tasks = [task];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TasksScreen(tasksRepository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TaskCard>(find.byType(TaskCard)).task, same(task));
    expect(find.text('Описание с сервера'), findsOneWidget);
    expect(find.text('Анна Петрова'), findsOneWidget);
    expect(find.text('Высокая'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates the first column and makes it available for new tasks', (
    tester,
  ) async {
    final repository = FakeTasksRepository();
    repository.columns = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TasksScreen(tasksRepository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Колонка'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateTaskColumnWindow), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '  Новая очередь  ');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(repository.submittedColumn!.name, 'Новая очередь');
    expect(find.text('Новая очередь'), findsOneWidget);
    expect(repository.boardRequests, 1);

    await tester.tap(find.text('Добавить задачу'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(CreateTaskWindow),
        matching: find.text('Новая очередь'),
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название *'),
      'В новой колонке',
    );
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(repository.submitted!.columnId, 5);
    expect(find.text('В новой колонке'), findsOneWidget);
  });

  testWidgets('creates a task and adds the returned card to the board', (
    tester,
  ) async {
    final repository = FakeTasksRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TasksScreen(tasksRepository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Добавить задачу'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(CreateTaskWindow),
        matching: find.text('В работе'),
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название *'),
      'Новая задача',
    );
    final columnField = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(columnField);
    await tester.tap(columnField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Общая очередь').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    expect(repository.submitted?.title, 'Новая задача');
    expect(repository.submitted?.columnId, 1);
    expect(find.widgetWithText(TaskCard, 'Новая задача'), findsOneWidget);
    expect(tester.widget<TaskCard>(find.byType(TaskCard)).task.description, '');
  });

  testWidgets('creates in the selected column even when it is not new', (
    tester,
  ) async {
    final repository = FakeTasksRepository();
    repository.columns = [repository.columns.first];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TasksScreen(tasksRepository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить задачу'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateTaskWindow), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название *'),
      'В выбранной колонке',
    );
    final responsible = find.byType(DropdownButtonFormField<int?>);
    await tester.ensureVisible(responsible);
    await tester.tap(responsible);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Администратор').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(repository.submitted?.columnId, 2);
    expect(find.text('В выбранной колонке'), findsOneWidget);
  });
}
