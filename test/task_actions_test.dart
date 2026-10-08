import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:crm_interface/modules/tasks/repos/request_error.dart';
import 'package:crm_interface/modules/tasks/widgets/task_actions.dart';
import 'package:crm_interface/modules/tasks/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const task = TaskboardTask(
  id: '12',
  columnId: '1',
  title: 'Старая задача',
  description: 'Описание',
  priority: 'high',
  subtasks: [],
  version: 4,
);

Future<void> openForm(
  WidgetTester tester,
  TaskCardAction action, {
  required Future<void> Function(EditTaskRequest) onEdit,
  required Future<void> Function(AssignTaskRequest) onAssign,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => TaskActionWindow(
                task: task,
                action: action,
                employees: const [TaskEmployee(id: 4, fullName: 'Анна')],
                onEdit: onEdit,
                onAssign: onAssign,
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
}

void main() {
  testWidgets(
    'edit validates title and sends metadata without unrelated fields',
    (tester) async {
      EditTaskRequest? request;
      await openForm(
        tester,
        TaskCardAction.edit,
        onEdit: (value) async {
          request = value;
        },
        onAssign: (_) async {},
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Название *'),
        '  ',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(request, isNull);
      expect(find.text('Введите название'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Название *'),
        'Новое название',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(request!.toApi(), {
        'title': 'Новое название',
        'description': 'Описание',
        'priority': 'high',
        'version': 4,
      });
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('assign supports explicit unassignment with null', (
    tester,
  ) async {
    AssignTaskRequest? request;
    await openForm(
      tester,
      TaskCardAction.assign,
      onEdit: (_) async {},
      onAssign: (value) async {
        request = value;
      },
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(request!.toApi(), {'employee_id': null});
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('server rejection preserves task form and user input', (
    tester,
  ) async {
    await openForm(
      tester,
      TaskCardAction.edit,
      onEdit: (_) async =>
          throw const TaskRequestException('Недостаточно прав'),
      onAssign: (_) async {},
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название *'),
      'Новый текст',
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Новый текст'), findsOneWidget);
    expect(find.text('Недостаточно прав'), findsOneWidget);
  });
}
