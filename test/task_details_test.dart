import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/tasks/models/task_details.dart';
import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:crm_interface/modules/tasks/repos/request_error.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/screens/tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/customer_tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/task_card.dart';
import 'package:crm_interface/modules/tasks/widgets/task_details.dart';
import 'package:crm_interface/modules/tasks/widgets/task_checklist_editor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> taskJson() => {
  'id': 12,
  'column_id': 1,
  'title': 'Проверить релиз',
  'description': 'Полное описание\nВторая строка',
  'status': 'in_progress',
  'priority': 'normal',
  'responsible_employee_id': 7,
  'responsible': {'id': 7, 'full_name': 'Исполнитель'},
  'created_by_employee_id': 3,
  'author': {'id': 3, 'full_name': 'Автор задачи'},
  'created_at': '2026-10-16T07:00:00Z',
  'updated_at': '2026-10-16T08:00:00Z',
  'due_date': '2026-10-18',
  'due_at': null,
  'timezone': 'Asia/Yekaterinburg',
  'subtasks': [
    {'id': 9, 'title': 'Запустить приложение', 'done': false, 'order': 0},
  ],
  'version': 4,
  'column_history': [
    {
      'previous_column': null,
      'new_column': {'id': 1, 'name': 'В работе'},
      'changed_at': '2026-10-16T07:00:00Z',
      'changed_by': {'id': 3, 'full_name': 'Автор задачи'},
      'reason': null,
    },
  ],
  'status_history': [],
  'assignment_history': [
    {
      'previous_employee': null,
      'new_employee': {'id': 7, 'full_name': 'Исполнитель'},
      'changed_at': '2026-10-16T08:00:00Z',
      'changed_by': {'id': 4, 'full_name': 'Назначивший сотрудник'},
      'reason': null,
    },
  ],
};

const testColumn = TaskboardColumn(
  id: '1',
  name: 'В работе',
  order: 0,
  countsAsDone: false,
  status: 'in_progress',
  version: 1,
);

class DetailsRepository extends TasksRepository {
  DetailsRepository() : super(ApiClient(SessionStore()));
  Map<String, dynamic> data = taskJson();
  final published = <TaskboardTask>[];
  int reads = 0;
  int boardReads = 0;
  int descriptionWrites = 0;
  int marks = 0;
  bool failRead = false;
  bool failDescription = false;
  bool failMark = false;
  bool failAssignment = false;
  bool loseAssignmentResponse = false;
  bool failEmployees = false;
  bool failParameters = false;
  int parameterWrites = 0;
  int assignmentWrites = 0;
  EditTaskRequest? parameterRequest;
  bool loseParametersResponse = false;
  int nextSubtaskId = 20;
  bool failFollowUp = false;
  Completer<TaskDetails>? nextRead;
  Completer<TaskboardTask>? save;
  UpdateTaskDescriptionRequest? descriptionRequest;
  MarkSubtaskRequest? markRequest;

  TaskboardTask get task => TaskboardTask.fromApi(data);

  @override
  Future<TaskDetails> getTaskDetails(String taskId) async {
    reads++;
    final pending = nextRead;
    nextRead = null;
    if (pending != null) return pending.future;
    if (failRead) throw const TaskRequestException('Нет доступа к задаче');
    return TaskDetails.fromApi(data);
  }

  @override
  Future<Taskboard> getTaskBoard() async {
    boardReads++;
    return Taskboard(columns: const [testColumn], tasks: [task]);
  }

  @override
  Future<TaskPage> getCustomerTasks(
    int customerId, {
    int limit = 20,
    int offset = 0,
    String sort = 'due_at',
  }) async => TaskPage(items: [task], total: 1, limit: limit, offset: offset);

  @override
  Future<TaskboardTask> updateDescription(
    String taskId,
    UpdateTaskDescriptionRequest request,
  ) async {
    descriptionWrites++;
    descriptionRequest = request;
    if (failDescription) throw const TaskRequestException('Конфликт версии');
    if (save != null) return save!.future;
    data['description'] = request.description;
    data['version'] = (data['version'] as int) + 1;
    if (failFollowUp) failRead = true;
    return task;
  }

  @override
  Future<TaskboardTask> markSubtask(
    String taskId,
    int subtaskId,
    MarkSubtaskRequest request,
  ) async {
    marks++;
    markRequest = request;
    if (failMark) {
      throw const TaskRequestException('Не удалось сохранить отметку');
    }
    (data['subtasks'] as List).first['done'] = request.done;
    data['version'] = (data['version'] as int) + 1;
    return task;
  }

  @override
  Future<TaskboardTask> editTask(String taskId, EditTaskRequest request) async {
    parameterWrites++;
    parameterRequest = request;
    if (failParameters) throw const TaskRequestException('Параметры отклонены');
    data['title'] = request.title;
    data['description'] = request.description;
    data['priority'] = request.priority.name;
    if (request.subtasks != null) {
      final previous = {
        for (final item in data['subtasks'] as List) item['id']: item,
      };
      data['subtasks'] = [
        for (var i = 0; i < request.subtasks!.length; i++)
          {
            'id': request.subtasks![i].id ?? nextSubtaskId++,
            'title': request.subtasks![i].title,
            'done': previous[request.subtasks![i].id]?['done'] ?? false,
            'order': i,
          },
      ];
    }
    data['version'] = (data['version'] as int) + 1;
    if (loseParametersResponse) {
      throw const TaskRequestException('Ответ сохранения потерян');
    }
    return task;
  }

  @override
  Future<List<TaskEmployee>> getEmployees() async {
    if (failEmployees) throw const TaskRequestException('Недостаточно прав');
    return const [
      TaskEmployee(id: 7, fullName: 'Исполнитель'),
      TaskEmployee(id: 8, fullName: 'Новый исполнитель'),
    ];
  }

  @override
  Future<TaskboardTask> assignTask(
    String taskId,
    AssignTaskRequest request,
  ) async {
    assignmentWrites++;
    if (failAssignment) {
      throw const TaskRequestException('Назначение отклонено');
    }
    data['responsible_employee_id'] = request.employeeId;
    data['responsible'] = request.employeeId == null
        ? null
        : {'id': request.employeeId, 'full_name': 'Новый исполнитель'};
    data['assignment_history'] = [
      {
        'previous_employee': {'id': 7, 'full_name': 'Исполнитель'},
        'new_employee': data['responsible'],
        'changed_at': '2026-10-16T09:00:00Z',
        'changed_by': {'id': 6, 'full_name': 'Новый назначивший'},
        'reason': null,
      },
    ];
    data['version'] = (data['version'] as int) + 1;
    if (loseAssignmentResponse) {
      throw const TaskRequestException('Ответ назначения потерян');
    }
    return task;
  }
}

Future<void> openDetails(
  WidgetTester tester,
  DetailsRepository repo, {
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => TaskDetailsWindow(
                task: repo.task,
                repository: repo,
                onChanged: (task) async => repo.published.add(task),
              ),
            ),
            child: const Text('Открыть'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> editDescription(WidgetTester tester, String value) async {
  await tester.tap(find.text('Изменить'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('task-description-editor')),
    value,
  );
}

Future<void> chooseExecutor(WidgetTester tester, String label) async {
  final field = find.byType(DropdownButtonFormField<int>);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> openParameters(WidgetTester tester, DetailsRepository repo) async {
  await openDetails(tester, repo);
  await tester.tap(find.text('Изменить параметры'));
  await tester.pumpAndSettle();
}

Future<void> saveParameters(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
  await tester.pumpAndSettle();
}

Future<void> refreshParameters(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Обновить состояние задачи'));
  await tester.tap(find.text('Обновить состояние задачи'));
  await tester.pumpAndSettle();
}

Finder checklistFields() => find.descendant(
  of: find.byType(TaskChecklistEditor),
  matching: find.byType(TextFormField),
);

Future<void> addChecklistRow(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text('Добавить подзадачу'));
  await tester.tap(find.text('Добавить подзадачу'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(checklistFields().last);
  await tester.enterText(checklistFields().last, title);
}

void main() {
  late DetailsRepository repo;
  setUp(() => repo = DetailsRepository());
  tearDown(() => repo.apiClient.dio.close(force: true));

  test(
    'checklist DTO distinguishes omission, replacement and explicit empty list',
    () {
      EditTaskRequest request(List<TaskSubtaskDraft>? list) => EditTaskRequest(
        title: 'Задача',
        description: '',
        priority: Priority.normal,
        version: 4,
        subtasks: list,
      );
      expect(request(null).toApi().containsKey('subtasks'), isFalse);
      expect(request([]).toApi()['subtasks'], []);
      expect(
        request(const [
          TaskSubtaskDraft(id: 9, title: 'Переименовать'),
          TaskSubtaskDraft(title: 'Новая'),
        ]).toApi()['subtasks'],
        [
          {'id': 9, 'title': 'Переименовать'},
          {'title': 'Новая'},
        ],
      );
    },
  );

  testWidgets(
    'checklist editor renames and adds while preserving completion marks',
    (tester) async {
      (repo.data['subtasks'] as List).first['done'] = true;
      await openParameters(tester, repo);
      await tester.ensureVisible(checklistFields().first);
      await tester.enterText(
        checklistFields().first,
        'Переименованная подзадача',
      );
      await addChecklistRow(tester, 'Новая подзадача');
      await saveParameters(tester);
      expect(
        repo.parameterRequest!.subtasks!.map((item) => item.toApi()).toList(),
        [
          {'id': 9, 'title': 'Переименованная подзадача'},
          {'title': 'Новая подзадача'},
        ],
      );
      expect(repo.published.last.subtasks.first.done, isTrue);
      expect(repo.published.last.subtasks.last.id, 20);
      expect(find.text('1 из 2'), findsOneWidget);
      expect(repo.assignmentWrites, 0);
    },
  );

  testWidgets('checklist editor reorders existing IDs without changing marks', (
    tester,
  ) async {
    (repo.data['subtasks'] as List).add({
      'id': 10,
      'title': 'Второй шаг',
      'done': true,
      'order': 1,
    });
    await openParameters(tester, repo);
    await tester.ensureVisible(find.byTooltip('Опустить подзадачу').first);
    await tester.tap(find.byTooltip('Опустить подзадачу').first);
    await tester.pumpAndSettle();
    await saveParameters(tester);
    expect(repo.parameterRequest!.subtasks!.map((item) => item.id), [10, 9]);
    expect(repo.published.last.subtasks.first.done, isTrue);
    expect(repo.published.last.subtasks.last.done, isFalse);
  });

  testWidgets('removing the last subtask sends explicit empty replacement', (
    tester,
  ) async {
    await openParameters(tester, repo);
    await tester.ensureVisible(find.byTooltip('Убрать подзадачу'));
    await tester.tap(find.byTooltip('Убрать подзадачу'));
    await tester.pumpAndSettle();
    await saveParameters(tester);
    expect(repo.parameterRequest!.subtasks, isEmpty);
    expect(repo.published.last.subtasks, isEmpty);
    expect(find.text('Подзадач нет.'), findsOneWidget);
  });

  testWidgets('blank added subtask is validated instead of silently skipped', (
    tester,
  ) async {
    await openParameters(tester, repo);
    await addChecklistRow(tester, '   ');
    await saveParameters(tester);
    expect(repo.parameterWrites, 0);
    expect(find.text('Введите название или уберите строку'), findsOneWidget);
  });

  testWidgets(
    'lost checklist-save response adopts server IDs and does not add twice',
    (tester) async {
      repo.loseParametersResponse = true;
      await openParameters(tester, repo);
      await addChecklistRow(tester, 'Новый шаг');
      await saveParameters(tester);
      expect(repo.parameterWrites, 1);
      await refreshParameters(tester);
      await saveParameters(tester);
      expect(repo.parameterWrites, 1);
      expect(repo.published.last.subtasks.length, 2);
      expect(repo.published.last.subtasks.last.id, 20);
      expect(find.text('Изменить параметры задачи'), findsNothing);
    },
  );

  testWidgets(
    'recovery preserves a peer completion mark while keeping a title draft',
    (tester) async {
      repo.failParameters = true;
      await openParameters(tester, repo);
      await tester.ensureVisible(checklistFields().first);
      await tester.enterText(checklistFields().first, 'Моё уточнение');
      await saveParameters(tester);
      repo.failParameters = false;
      (repo.data['subtasks'] as List).first['done'] = true;
      repo.data['version'] = 5;
      await refreshParameters(tester);
      await saveParameters(tester);
      expect(repo.parameterRequest!.version, 5);
      expect(repo.published.last.subtasks.single.title, 'Моё уточнение');
      expect(repo.published.last.subtasks.single.done, isTrue);
    },
  );

  testWidgets(
    'concurrent checklist change blocks replacement until explicitly accepted',
    (tester) async {
      repo.failParameters = true;
      await openParameters(tester, repo);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Название *'),
        'Мой заголовок',
      );
      await tester.ensureVisible(checklistFields().first);
      await tester.enterText(checklistFields().first, 'Мой шаг');
      await saveParameters(tester);
      repo.failParameters = false;
      (repo.data['subtasks'] as List).add({
        'id': 99,
        'title': 'Добавлено коллегой',
        'done': false,
        'order': 1,
      });
      repo.data['version'] = 5;
      await refreshParameters(tester);
      expect(
        find.textContaining('Подзадачи изменились на сервере'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Сохранить'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Загрузить актуальные подзадачи'));
      await tester.tap(find.text('Загрузить актуальные подзадачи'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Оставить черновик'));
      await tester.pumpAndSettle();
      expect(find.text('Мой шаг'), findsOneWidget);
      await tester.tap(find.text('Загрузить актуальные подзадачи'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Загрузить список'));
      await tester.pumpAndSettle();
      expect(find.text('Мой заголовок'), findsOneWidget);
      expect(find.text('Добавлено коллегой'), findsWidgets);
      await saveParameters(tester);
      expect(repo.parameterRequest!.subtasks, isNull);
      expect(repo.published.last.subtasks.map((item) => item.id), [9, 99]);
      expect(repo.published.last.title, 'Мой заголовок');
    },
  );

  testWidgets('partial assignment failure never resubmits added subtasks', (
    tester,
  ) async {
    repo.failAssignment = true;
    await openParameters(tester, repo);
    await addChecklistRow(tester, 'Добавлено один раз');
    await chooseExecutor(tester, 'Новый исполнитель');
    await saveParameters(tester);
    expect(repo.parameterWrites, 1);
    repo.failAssignment = false;
    await refreshParameters(tester);
    await saveParameters(tester);
    expect(repo.parameterWrites, 1);
    expect(repo.assignmentWrites, 2);
    expect(repo.published.last.subtasks.length, 2);
  });

  testWidgets('editor caps task checklist at 50 rows', (tester) async {
    repo.data['subtasks'] = [
      for (var i = 0; i < 50; i++)
        {'id': i + 1, 'title': 'Шаг $i', 'done': false, 'order': i},
    ];
    await openParameters(tester, repo);
    final button = find
        .ancestor(
          of: find.text('Добавить подзадачу'),
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        )
        .first;
    expect(tester.widget<TextButton>(button).onPressed, isNull);
    expect(checklistFields(), findsNWidgets(50));
  });

  test(
    'author and assignment actor are distinct, missing provenance is unknown',
    () {
      final details = TaskDetails.fromApi(taskJson());
      expect(details.author!.id, 3);
      expect(details.currentAssignment!.changedBy.id, 4);
      expect(details.createdAt!.isUtc, isTrue);
      expect(details.columnName, 'В работе');
      final json = taskJson()
        ..remove('author')
        ..remove('created_by_employee_id');
      json['assignment_history'] = [];
      final legacy = TaskDetails.fromApi(json);
      expect(legacy.author, isNull);
      expect(legacy.currentAssignment, isNull);
    },
  );

  test(
    'current assignment uses latest event, not an old matching executor',
    () {
      final json = taskJson();
      final history = json['assignment_history'] as List;
      history.insert(0, {
        ...history.first as Map<String, dynamic>,
        'changed_at': '2026-10-16T10:00:00Z',
        'new_employee': null,
      });
      expect(TaskDetails.fromApi(json).currentAssignment, isNull);
    },
  );

  for (final description in <String?>['Новый текст', null]) {
    test(
      'description PATCH sends only description/version: $description',
      () async {
        repo.apiClient.dio.interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (options, handler) {
              expect(options.method, 'PATCH');
              expect(options.path, '/tasks/12');
              expect(options.data, {'description': description, 'version': 4});
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: taskJson()
                    ..['description'] = description
                    ..['version'] = 5,
                ),
              );
            },
          ),
        );
        final updated = await TasksRepository(repo.apiClient).updateDescription(
          '12',
          UpdateTaskDescriptionRequest(description: description, version: 4),
        );
        expect(updated.description, description);
        expect(updated.version, 5);
      },
    );
  }

  testWidgets(
    'loads full details, authors, dates and empty states without extras',
    (tester) async {
      repo.data['description'] = List.filled(40, 'Полный текст').join('\n');
      repo.data['subtasks'] = [];
      await openDetails(tester, repo);
      expect(find.text(repo.task.description!), findsOneWidget);
      expect(find.text('Автор задачи'), findsOneWidget);
      expect(find.text('Назначивший сотрудник'), findsOneWidget);
      expect(find.text('18.10.2026 · весь день'), findsOneWidget);
      expect(find.text('Подзадач нет.'), findsOneWidget);
      expect(find.text('Комментарии'), findsNothing);
      expect(find.text('Файлы'), findsNothing);
      expect(repo.published.single.version, 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initial failure offers retry; disposed pending GET is harmless',
    (tester) async {
      repo.failRead = true;
      await openDetails(tester, repo);
      expect(find.text('Нет доступа к задаче'), findsOneWidget);
      repo.failRead = false;
      repo.nextRead = Completer<TaskDetails>();
      final pending = repo.nextRead!;
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      await tester.tap(find.byTooltip('Закрыть карточку задачи'));
      await tester.pumpAndSettle();
      pending.complete(TaskDetails.fromApi(taskJson()));
      await tester.pump();
      expect(find.byType(TaskDetailsWindow), findsNothing);
      expect(repo.published, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saves description and publishes confirmed whole task/version', (
    tester,
  ) async {
    await openDetails(tester, repo);
    await editDescription(tester, 'Изменённое описание\nПодробности');
    await tester.tap(find.text('Сохранить описание'));
    await tester.pumpAndSettle();
    expect(repo.descriptionRequest!.version, 4);
    expect(
      repo.descriptionRequest!.description,
      'Изменённое описание\nПодробности',
    );
    expect(repo.published.last.version, 5);
    expect(find.byKey(const Key('task-description-editor')), findsNothing);
    expect(find.text('Изменённое описание\nПодробности'), findsOneWidget);
  });

  testWidgets('clearing description sends null, not other fields', (
    tester,
  ) async {
    await openDetails(tester, repo);
    await editDescription(tester, '   ');
    await tester.tap(find.text('Сохранить описание'));
    await tester.pumpAndSettle();
    expect(repo.descriptionRequest!.description, isNull);
    expect(find.text('Описание пока не добавлено.'), findsOneWidget);
  });

  testWidgets('Esc protects draft and Ctrl+Enter saves it', (tester) async {
    await openDetails(tester, repo);
    await editDescription(tester, 'Черновик');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Отменить изменения?'), findsOneWidget);
    await tester.tap(find.text('Продолжить редактирование'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('task-description-editor')),
          )
          .controller!
          .text,
      'Черновик',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(repo.descriptionWrites, 1);
    expect(find.text('Черновик'), findsOneWidget);
  });

  testWidgets('pending save blocks duplicate submit and closing', (
    tester,
  ) async {
    await openDetails(tester, repo);
    repo.save = Completer<TaskboardTask>();
    await editDescription(tester, 'Сохранённое описание');
    await tester.tap(find.text('Сохранить описание'));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton &&
                  widget.tooltip == 'Закрыть карточку задачи',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(TaskDetailsWindow), findsOneWidget);
    expect(repo.descriptionWrites, 1);
    repo.data['description'] = 'Сохранённое описание';
    repo.data['version'] = 5;
    repo.save!.complete(repo.task);
    await tester.pumpAndSettle();
    expect(find.text('Сохранённое описание'), findsOneWidget);
  });

  testWidgets('conflict retains draft and blocks blind retry until refresh', (
    tester,
  ) async {
    await openDetails(tester, repo);
    repo.failDescription = true;
    await editDescription(tester, 'Не потерять');
    await tester.tap(find.text('Сохранить описание'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Конфликт версии'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Сохранить описание'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('task-description-editor')),
          )
          .controller!
          .text,
      'Не потерять',
    );
    await tester.tap(find.byTooltip('Обновить карточку задачи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить редактирование'));
    await tester.pumpAndSettle();
    expect(repo.descriptionWrites, 1);
    await tester.tap(find.byTooltip('Обновить карточку задачи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Не сохранять'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-description-editor')), findsNothing);
    expect(find.text('Полное описание\nВторая строка'), findsOneWidget);
  });

  testWidgets('failed follow-up GET keeps saved DTO and disables stale edits', (
    tester,
  ) async {
    await openDetails(tester, repo);
    repo.failFollowUp = true;
    await editDescription(tester, 'Уже сохранено');
    await tester.tap(find.text('Сохранить описание'));
    await tester.pumpAndSettle();
    expect(repo.published.last.description, 'Уже сохранено');
    expect(find.text('Уже сохранено'), findsOneWidget);
    expect(find.textContaining('Данные требуют обновления'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Изменить'))
          .onPressed,
      isNull,
    );
    repo.failRead = false;
    await tester.tap(find.byTooltip('Обновить карточку задачи'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Данные требуют обновления'), findsNothing);
    expect(repo.descriptionWrites, 1);
  });

  testWidgets('subtask uses latest task version and refreshes progress', (
    tester,
  ) async {
    await openDetails(tester, repo);
    await tester.tap(find.byKey(const ValueKey('task-detail-subtask-9')));
    await tester.pumpAndSettle();
    expect(repo.markRequest!.version, 4);
    expect(repo.markRequest!.done, isTrue);
    expect(find.text('1 из 1'), findsOneWidget);
    expect(repo.published.last.subtasks.single.done, isTrue);
    expect(repo.published.last.version, 5);
  });

  testWidgets('one parameters form saves metadata and assignment together', (
    tester,
  ) async {
    await openDetails(tester, repo);
    await tester.tap(find.text('Изменить параметры'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название *'),
      'Новое название',
    );
    await chooseExecutor(tester, 'Новый исполнитель');
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Новый назначивший'), findsOneWidget);
    expect(find.text('Новое название'), findsOneWidget);
    expect(find.text('Автор задачи'), findsOneWidget);
    expect(repo.published.last.responsibleEmployeeId, 8);
    expect(repo.parameterWrites, 1);
    expect(repo.assignmentWrites, 1);
    expect(find.text('Назначить ответственного'), findsNothing);
  });

  testWidgets('unchanged parameters close without either mutation', (
    tester,
  ) async {
    await openParameters(tester, repo);
    await saveParameters(tester);
    expect(repo.parameterWrites, 0);
    expect(repo.assignmentWrites, 0);
    expect(find.text('Изменить параметры задачи'), findsNothing);
  });

  testWidgets('only executor change skips metadata PATCH', (tester) async {
    await openParameters(tester, repo);
    await chooseExecutor(tester, 'Новый исполнитель');
    await saveParameters(tester);
    expect(repo.parameterWrites, 0);
    expect(repo.assignmentWrites, 1);
    expect(repo.published.last.responsibleEmployeeId, 8);
  });

  testWidgets('combined form supports clearing executor', (tester) async {
    await openParameters(tester, repo);
    await chooseExecutor(tester, 'Без ответственного');
    await saveParameters(tester);
    expect(repo.parameterWrites, 0);
    expect(repo.assignmentWrites, 1);
    expect(repo.published.last.responsibleEmployeeId, isNull);
  });

  testWidgets(
    'partial success retries only assignment and preserves external metadata',
    (tester) async {
      repo.failAssignment = true;
      await openParameters(tester, repo);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Название *'),
        'Сохранённое название',
      );
      await chooseExecutor(tester, 'Новый исполнитель');
      await saveParameters(tester);
      expect(repo.parameterWrites, 1);
      expect(repo.assignmentWrites, 1);
      expect(repo.published.last.title, 'Сохранённое название');
      expect(find.textContaining('Параметры уже сохранены'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Сохранить'),
            )
            .onPressed,
        isNull,
      );
      // Another employee edits a field the user never touched before recovery.
      repo.data['description'] = 'Изменено коллегой';
      repo.data['version'] = 6;
      repo.failAssignment = false;
      await refreshParameters(tester);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Описание'),
            )
            .initialValue,
        'Изменено коллегой',
      );
      await saveParameters(tester);
      expect(repo.parameterWrites, 1);
      expect(repo.assignmentWrites, 2);
      expect(repo.data['description'], 'Изменено коллегой');
      expect(repo.published.last.responsibleEmployeeId, 8);
    },
  );

  testWidgets(
    'lost assignment acknowledgement is resolved by GET without duplicate commands',
    (tester) async {
      repo.loseAssignmentResponse = true;
      await openParameters(tester, repo);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Название *'),
        'Название сохранено',
      );
      await chooseExecutor(tester, 'Новый исполнитель');
      await saveParameters(tester);
      expect(find.textContaining('Назначение не подтверждено'), findsOneWidget);
      expect(repo.data['responsible_employee_id'], 8);
      await refreshParameters(tester);
      await saveParameters(tester);
      expect(repo.parameterWrites, 1);
      expect(repo.assignmentWrites, 1);
      expect(find.text('Изменить параметры задачи'), findsNothing);
      expect(repo.published.last.responsibleEmployeeId, 8);
    },
  );

  testWidgets(
    'failed metadata does not send assignment and recovery retains both edits',
    (tester) async {
      repo.failParameters = true;
      await openParameters(tester, repo);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Название *'),
        'Мой черновик',
      );
      await chooseExecutor(tester, 'Новый исполнитель');
      await saveParameters(tester);
      expect(repo.parameterWrites, 1);
      expect(repo.assignmentWrites, 0);
      repo.failParameters = false;
      await refreshParameters(tester);
      expect(find.text('Мой черновик'), findsOneWidget);
      await saveParameters(tester);
      expect(repo.parameterWrites, 2);
      expect(repo.assignmentWrites, 1);
      expect(repo.published.last.title, 'Мой черновик');
    },
  );

  testWidgets('missing employee list does not block metadata editing', (
    tester,
  ) async {
    repo.failEmployees = true;
    await openParameters(tester, repo);
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .onChanged,
      isNull,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название *'),
      'Только параметры',
    );
    await saveParameters(tester);
    expect(repo.parameterWrites, 1);
    expect(repo.assignmentWrites, 0);
    expect(repo.published.last.title, 'Только параметры');
  });

  testWidgets('closed tasks stay read-only; completed cannot be reassigned', (
    tester,
  ) async {
    repo.data['status'] = 'completed';
    await openDetails(tester, repo);
    expect(find.text('Назначить ответственного'), findsNothing);
    await tester.tap(find.text('Изменить параметры'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .onChanged,
      isNull,
    );
    expect(
      find.text('В этом статусе нельзя менять исполнителя.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Закрыть карточку задачи'));
    await tester.pumpAndSettle();
    repo.data['status'] = 'confirmed';
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(
      find.text('Задача закрыта. Доступен только просмотр.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Изменить'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('task-detail-subtask-9')),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets('narrow window scrolls without overflow', (tester) async {
    await openDetails(tester, repo, size: const Size(390, 740));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byType(Dialog));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(390));
    await tester.ensureVisible(find.text('Создал'));
    await tester.pumpAndSettle();
    expect(find.text('Автор задачи'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('older follow-up GET cannot erase the saved description', (
    tester,
  ) async {
    await openDetails(tester, repo);
    final pending = Completer<TaskDetails>();
    repo.nextRead = pending;
    await editDescription(tester, 'Новая серверная версия');
    await tester.tap(find.text('Сохранить описание'));
    await tester.pump();
    pending.complete(TaskDetails.fromApi(taskJson()));
    await tester.pumpAndSettle();
    expect(find.text('Новая серверная версия'), findsOneWidget);
    expect(repo.published.last.version, 5);
    expect(find.textContaining('устаревшие данные'), findsOneWidget);
  });

  testWidgets('failed checkbox mutation does not fake completion', (
    tester,
  ) async {
    await openDetails(tester, repo);
    repo.failMark = true;
    await tester.tap(find.byKey(const ValueKey('task-detail-subtask-9')));
    await tester.pumpAndSettle();
    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('task-detail-subtask-9')),
    );
    expect(checkbox.value, isFalse);
    expect(checkbox.onChanged, isNull);
    expect(find.textContaining('Не удалось сохранить отметку'), findsOneWidget);
  });

  for (final compact in [false, true]) {
    testWidgets(
      'card tap opens but menu/checklist/drag do not, compact=$compact',
      (tester) async {
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  child: TaskCard(
                    task: repo.task,
                    compact: compact,
                    onOpen: () => opened++,
                    onAction: (_) {},
                    onSubtaskChanged: (_, _) async {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Проверить релиз'));
        await tester.pumpAndSettle();
        expect(opened, 1);
        await tester.tap(find.byTooltip('Действия с задачей'));
        await tester.pumpAndSettle();
        expect(opened, 1);
        await tester.tap(find.text('История задачи'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Подзадачи · 0/1'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        expect(opened, 1);
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Проверить релиз')),
        );
        await gesture.moveBy(const Offset(70, 0));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(opened, 1);
      },
    );
  }

  testWidgets(
    'board click opens details, pauses polling and keeps saved card',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TasksScreen(tasksRepository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверить релиз'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailsWindow), findsOneWidget);
      final reads = repo.boardReads;
      await tester.pump(const Duration(seconds: 21));
      expect(repo.boardReads, reads);
      await editDescription(tester, 'Новый текст на доске');
      await tester.tap(find.text('Сохранить описание'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Закрыть карточку задачи'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TaskCard>(find.byType(TaskCard)).task.description,
        'Новый текст на доске',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('compact customer task also opens the same detail window', (
    tester,
  ) async {
    repo.data['customer'] = {'id': 5, 'full_name': 'Клиент'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerTasksPanel(customerId: 5, repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверить релиз'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailsWindow), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть карточку задачи'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailsWindow), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
