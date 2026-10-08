import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TaskboardTask makeTask({
  String title = 'Позвонить клиенту',
  String? description,
  String priority = 'normal',
  String? responsibleName,
  int? responsibleId,
  DateTime? dueAt,
  List<TaskboardTaskSubtask> subtasks = const [],
  String status = 'new',
}) {
  return TaskboardTask(
    id: '101',
    columnId: '1',
    title: title,
    description: description,
    priority: priority,
    responsibleEmployeeId: responsibleId,
    responsibleEmployeeName: responsibleName,
    dueAt: dueAt,
    subtasks: subtasks,
    version: 1,
    status: status,
  );
}

Future<void> pumpCard(
  WidgetTester tester,
  TaskboardTask task, {
  ValueChanged<TaskCardAction>? onAction,
  bool compact = false,
  double width = 300,
  Future<void> Function(TaskboardTaskSubtask, bool)? onSubtaskChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: TaskCard(
              task: task,
              onAction: onAction,
              compact: compact,
              onSubtaskChanged: onSubtaskChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'customer variant is substantially shorter and uses horizontal metadata',
    (tester) async {
      final task = makeTask(
        description: 'Описание первой строки\nОписание второй строки\nОписание третьей строки',
        responsibleName: 'Анна Петрова',
        responsibleId: 4,
        dueAt: DateTime(2026, 10, 7, 9, 30),
        subtasks: const [
          TaskboardTaskSubtask(
            id: 1,
            title: 'Уточнить запись',
            done: false,
            order: 0,
          ),
        ],
      );
      await pumpCard(tester, task, width: 760);
      final regularHeight = tester.getSize(find.byType(TaskCard)).height;
      await pumpCard(tester, task, compact: true, width: 760);
      final compactHeight = tester.getSize(find.byType(TaskCard)).height;
      expect(compactHeight, lessThan(regularHeight * .7));
      expect(compactHeight, lessThan(150));
      expect(find.text('Новая'), findsOneWidget);
      expect(find.text('Анна Петрова'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Анна Петрова')).dy,
        closeTo(tester.getCenter(find.text('Срок: 07.10.2026 09:30')).dy, 2),
      );
      expect(tester.widget<Text>(find.text(task.description!)).maxLines, 1);
      expect(tester.widget<Text>(find.text(task.title)).maxLines, 1);
      expect(find.byTooltip(task.description!), findsOneWidget);
      expect(find.byTooltip(task.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact cards keep actions and editable subtasks', (
    tester,
  ) async {
    final actions = <TaskCardAction>[];
    final checked = <bool>[];
    await pumpCard(
      tester,
      makeTask(
        subtasks: const [
          TaskboardTaskSubtask(
            id: 1,
            title: 'Позвонить',
            done: false,
            order: 0,
          ),
        ],
      ),
      compact: true,
      width: 760,
      onAction: actions.add,
      onSubtaskChanged: (_, done) async => checked.add(done),
    );
    expect(find.text('Позвонить'), findsNothing);
    await tester.tap(find.byTooltip('Действия с задачей'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();
    expect(actions, [TaskCardAction.edit]);
    await tester.tap(find.textContaining('Подзадачи ·'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(checked, [true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact empty metadata has no meaningless zero progress bar', (
    tester,
  ) async {
    await pumpCard(tester, makeTask(), compact: true);
    expect(find.text('Без ответственного'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Без подзадач'), findsNothing);
    expect(find.textContaining('Подзадачи ·'), findsNothing);
    expect(tester.getSize(find.byType(TaskCard)).height, lessThan(110));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact long content adapts to narrow and wide customer panels',
    (tester) async {
      final task = makeTask(
        title: List.filled(15, 'Длинное название').join(' '),
        description: List.filled(15, 'Длинное описание').join(' '),
        responsibleName: 'Сотрудник с очень длинным именем и фамилией',
        responsibleId: 4,
        priority: 'urgent',
        status: 'completed',
        dueAt: DateTime(2026, 10, 7, 9, 30),
        subtasks: const [
          TaskboardTaskSubtask(id: 1, title: 'Действие', done: false, order: 0),
        ],
      );
      for (final width in [280.0, 380.0, 760.0]) {
        await pumpCard(tester, task, compact: true, width: width);
        expect(tester.getSize(find.byType(TaskCard)).width, width);
        expect(find.text('Выполнена — на проверке'), findsOneWidget);
        expect(find.text('Срочная'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'card menu matches template actions and deletion is unavailable',
    (tester) async {
      final actions = <TaskCardAction>[];
      await pumpCard(tester, makeTask(), onAction: actions.add);
      final menu = find.byType(PopupMenuButton<TaskCardAction>);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text('Назначить ответственного'), findsOneWidget);
      expect(
        tester
            .widget<PopupMenuItem<TaskCardAction>>(
              find.widgetWithText(
                PopupMenuItem<TaskCardAction>,
                'Удалить задачу',
              ),
            )
            .enabled,
        isFalse,
      );
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();
      expect(actions, [TaskCardAction.edit]);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Назначить ответственного'));
      await tester.pumpAndSettle();
      expect(actions.last, TaskCardAction.assign);
    },
  );
  testWidgets('shows task metadata and actual subtask progress', (
    tester,
  ) async {
    await pumpCard(
      tester,
      makeTask(
        description: 'Уточнить удобное время записи',
        priority: 'urgent',
        responsibleName: 'Анна Петрова',
        responsibleId: 4,
        dueAt: DateTime(2026, 10, 7, 9, 30),
        subtasks: const [
          TaskboardTaskSubtask(
            id: 1,
            title: 'Проверить запись',
            done: true,
            order: 0,
          ),
          TaskboardTaskSubtask(
            id: 2,
            title: 'Позвонить',
            done: false,
            order: 1,
          ),
        ],
      ),
    );
    expect(find.text('Позвонить клиенту'), findsOneWidget);
    expect(find.text('Уточнить удобное время записи'), findsOneWidget);
    expect(find.text('Срочная'), findsOneWidget);
    expect(find.text('Анна Петрова'), findsOneWidget);
    expect(find.text('Срок: 07.10.2026 09:30'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, 0.5);
    expect(progress.semanticsLabel, 'Подзадачи: выполнено 1 из 2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('handles missing fields and zero subtasks without fake data', (
    tester,
  ) async {
    await pumpCard(tester, makeTask());
    expect(find.text('Без ответственного'), findsOneWidget);
    expect(find.text('Без подзадач'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses natural height and truncates long text', (tester) async {
    await pumpCard(tester, makeTask());
    final shortHeight = tester.getSize(find.byType(TaskCard)).height;
    final title = List.filled(15, 'Очень длинное название').join(' ');
    final description = List.filled(20, 'Подробное описание задачи').join(' ');
    await pumpCard(
      tester,
      makeTask(
        title: title,
        description: description,
        responsibleName: 'Очень длинное имя ответственного сотрудника',
        dueAt: DateTime(2026, 10, 7, 9, 30),
      ),
    );
    expect(
      tester.getSize(find.byType(TaskCard)).height,
      greaterThan(shortHeight),
    );
    expect(tester.getSize(find.byType(TaskCard)).width, 300);
    for (final text in [title, description]) {
      final widget = tester.widget<Text>(find.text(text));
      expect(widget.maxLines, 3);
      expect(widget.overflow, TextOverflow.ellipsis);
      expect(find.byTooltip(text), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not label an unnamed assigned employee as unassigned', (
    tester,
  ) async {
    await pumpCard(tester, makeTask(responsibleId: 4, description: '  '));
    expect(find.text('Сотрудник #4'), findsOneWidget);
    expect(find.text('Без ответственного'), findsNothing);
    expect(find.text('  '), findsNothing);
  });

  for (final entry in {
    'low': 'Низкая',
    'normal': 'Обычная',
    'high': 'Высокая',
    'urgent': 'Срочная',
    'future-priority': 'Неизвестный',
  }.entries) {
    testWidgets('renders priority ${entry.key}', (tester) async {
      await pumpCard(tester, makeTask(priority: entry.key));
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
