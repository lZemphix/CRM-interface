import 'dart:async';

import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/create_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final columns = [
    const TaskboardColumn(
      id: '1',
      name: 'Общая очередь',
      order: 0,
      countsAsDone: false,
      status: 'new',
      version: 1,
    ),
  ];

  testWidgets('validates fields and submits a typed request', (tester) async {
    CreateTaskRequest? request;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => CreateTaskWindow(
                    columns: columns,
                    employees: const [
                      TaskEmployee(id: 4, fullName: 'Администратор'),
                    ],
                    onCreate: (value) async {
                      request = value;
                    },
                  ),
                );
              },
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(find.text('Введите название задачи'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название *'),
      '  Проверить API  ',
    );
    await tester.ensureVisible(find.text('Добавить подзадачу'));
    await tester.tap(find.text('Добавить подзадачу'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(find.text('Введите название или удалите подзадачу'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Подзадача'),
      '  Отправить POST  ',
    );
    await tester.ensureVisible(find.text('Создать'));
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    expect(request, isNotNull);
    expect(request!.title, 'Проверить API');
    expect(request!.columnId, 1);
    expect(request!.priority, Priority.normal);
    expect(request!.responsibleEmployeeId, isNull);
    expect(request!.subtasks.single.title, 'Отправить POST');
    expect(request!.toApi()['subtasks'], [
      {'title': 'Отправить POST'},
    ]);
  });

  testWidgets('keeps subtask identities when the middle row is removed', (
    tester,
  ) async {
    CreateTaskRequest? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateTaskWindow(
            columns: columns,
            employees: const [],
            onCreate: (value) async => request = value,
          ),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название *'),
      'Задача с подзадачами',
    );
    final titles = ['Первая', 'Вторая', 'Третья'];
    for (var index = 0; index < titles.length; index++) {
      final addButton = find.text('Добавить подзадачу');
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Подзадача').at(index),
        titles[index],
      );
    }

    final middleRow = find.ancestor(
      of: find.widgetWithText(TextFormField, 'Подзадача').at(1),
      matching: find.byType(Row),
    );
    final deleteButton = find.descendant(
      of: middleRow,
      matching: find.byTooltip('Удалить подзадачу'),
    );
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('Первая'), findsOneWidget);
    expect(find.text('Вторая'), findsNothing);
    expect(find.text('Третья'), findsOneWidget);

    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(request!.subtasks.map((subtask) => subtask.title), [
      'Первая',
      'Третья',
    ]);
  });

  testWidgets('disables submission while creation is pending', (tester) async {
    final completion = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateTaskWindow(
            columns: columns,
            employees: const [],
            onCreate: (_) {
              attempts++;
              return completion.future;
            },
          ),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название *'),
      'Ожидание ответа',
    );
    await tester.tap(find.text('Создать'));
    await tester.pump();
    final submitButton = find.widgetWithText(FilledButton, 'Создаём…');
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNull);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Отмена'))
          .onPressed,
      isNull,
    );
    await tester.tap(submitButton);
    expect(attempts, 1);

    completion.completeError(Exception('Network error'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Создать'))
          .onPressed,
      isNotNull,
    );
    expect(find.text('Ожидание ответа'), findsOneWidget);
  });

  testWidgets('keeps entered data when creation fails', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CreateTaskWindow(
                  columns: columns,
                  employees: const [],
                  onCreate: (_) async {
                    attempts++;
                    if (attempts == 1) throw Exception('Network error');
                  },
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
      'Не потерять данные',
    );
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось создать задачу. Попробуйте ещё раз.'),
      findsOneWidget,
    );
    expect(find.text('Не потерять данные'), findsOneWidget);

    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(CreateTaskWindow), findsNothing);
  });
}
