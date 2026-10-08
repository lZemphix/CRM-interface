import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:crm_interface/modules/tasks/repos/request_error.dart';
import 'package:crm_interface/modules/tasks/widgets/create_task.dart';
import 'package:crm_interface/modules/tasks/widgets/task_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TaskboardColumn column(String status, {String id = '1'}) => TaskboardColumn(
  id: id,
  name: status,
  order: 0,
  countsAsDone: status == 'confirmed',
  status: status,
  version: 1,
);

Future<void> openTaskForm(
  WidgetTester tester,
  List<TaskboardColumn> columns,
  Future<void> Function(CreateTaskRequest) onCreate,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => CreateTaskWindow(
                columns: columns,
                employees: const [TaskEmployee(id: 4, fullName: 'Исполнитель')],
                onCreate: onCreate,
              ),
            ),
            child: const Text('Открыть'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Название *'),
    'Задача',
  );
}

void main() {
  test('board DTO accepts a neutral column without treating it as done', () {
    final column = TaskboardColumn.fromApi({
      'id': 9,
      'name': 'Ожидание',
      'order': 0,
      'counts_as_done': false,
      'status': null,
      'version': 1,
    });
    expect(column.status, isNull);
    expect(column.countsAsDone, isFalse);
    expect(column.canCreateTask, isTrue);
    expect(column.requiresExecutor, isFalse);
    expect(column.requiresReason, isFalse);
  });
  testWidgets('neutral column creates a new task without executor or reason', (
    tester,
  ) async {
    CreateTaskRequest? sent;
    const neutral = TaskboardColumn(
      id: '9',
      name: 'Ожидание',
      order: 0,
      countsAsDone: false,
      status: null,
      version: 1,
    );
    await openTaskForm(tester, [neutral], (value) async => sent = value);
    expect(find.text('Причина доработки *'), findsNothing);
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(sent!.columnId, 9);
    expect(sent!.responsibleEmployeeId, isNull);
    expect(sent!.toApi().containsKey('status'), isFalse);
  });

  for (final status in ['in_progress', 'completed']) {
    testWidgets('$status requires an executor and preserves the column', (
      tester,
    ) async {
      CreateTaskRequest? sent;
      await openTaskForm(tester, [
        column(status),
      ], (value) async => sent = value);
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(sent, isNull);
      expect(
        find.text('Для этой колонки выберите ответственного'),
        findsOneWidget,
      );
      final field = find.byType(DropdownButtonFormField<int?>);
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Исполнитель').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(sent!.responsibleEmployeeId, 4);
      expect(sent!.columnId, 1);
      expect(sent!.dueAt, isNull);
      expect(sent!.customerId, isNull);
    });
  }

  testWidgets('rework requires a reason and submits trimmed text', (
    tester,
  ) async {
    CreateTaskRequest? sent;
    await openTaskForm(tester, [
      column('rework'),
    ], (value) async => sent = value);
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(sent, isNull);
    expect(find.text('Укажите причину доработки'), findsOneWidget);
    final reason = find.widgetWithText(TextFormField, 'Причина доработки *');
    await tester.ensureVisible(reason);
    await tester.enterText(reason, '  Проверить результат  ');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(sent!.toApi()['reason'], 'Проверить результат');
  });

  testWidgets('closed and unknown statuses stay visible but are disabled', (
    tester,
  ) async {
    await openTaskForm(tester, [
      column('confirmed'),
      column('cancelled', id: '2'),
      column('future_status', id: '3'),
      column('new', id: '4'),
    ], (_) async {});
    final field = tester.widget<DropdownButtonFormField<int>>(
      find.byType(DropdownButtonFormField<int>),
    );
    expect(field.initialValue, 4);
    final dropdown = tester.widget<DropdownButton<int>>(
      find.descendant(
        of: find.byType(DropdownButtonFormField<int>),
        matching: find.byType(DropdownButton<int>),
      ),
    );
    expect(dropdown.items!.map((item) => item.enabled), [
      false,
      false,
      false,
      true,
    ]);
  });

  testWidgets('displays API rejection without losing the form', (tester) async {
    await openTaskForm(tester, [column('new')], (_) async {
      throw const TaskRequestException(
        'Недостаточно прав для выбранной колонки.',
      );
    });
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(
      find.text('Недостаточно прав для выбранной колонки.'),
      findsOneWidget,
    );
    expect(find.text('Задача'), findsOneWidget);
    expect(find.byType(CreateTaskWindow), findsOneWidget);
  });

  test('does not expose server internals on 500', () {
    final options = RequestOptions(path: '/tasks');
    final error = TaskRequestException.fromDio(
      DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 500,
          data: {
            'detail': {'message': 'Secret traceback'},
          },
        ),
      ),
    );
    expect(error.message, isNot(contains('Secret')));
  });

  testWidgets(
    'all-day deadline keeps the calendar date, not device conversion',
    (tester) async {
      final task = TaskboardTask.fromApi({
        'id': 1,
        'column_id': 1,
        'title': 'На весь день',
        'description': null,
        'priority': 'normal',
        'responsible_employee_id': null,
        'responsible': null,
        'customer': null,
        'branch_id': null,
        'subtasks': [],
        'version': 1,
        'due_date': '2026-10-08',
        'due_at': '2026-10-08T18:59:59.999999Z',
        'timezone': 'Asia/Yekaterinburg',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 300, child: TaskCard(task: task)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(task.dueDate, DateTime(2026, 10, 8));
      expect(find.text('Срок: 08.10.2026'), findsOneWidget);
      expect(find.textContaining('23:59'), findsNothing);
    },
  );
}
