import 'dart:async';

import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/repos/request_error.dart';
import 'package:crm_interface/modules/tasks/widgets/task_subtasks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('template checklist uses a compact row and progress in summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: TaskSubtasks(
              taskId: '12',
              subtasks: [
                TaskboardTaskSubtask(
                  id: 1,
                  title: 'Шаг',
                  done: false,
                  order: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Подзадачи · 0/1'), findsOneWidget);
    await tester.tap(find.text('Подзадачи · 0/1'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(CheckboxListTile)).height,
      lessThanOrEqualTo(32),
    );
  });
  const subtasks = [
    TaskboardTaskSubtask(id: 1, title: 'Первый шаг', done: false, order: 0),
  ];

  testWidgets(
    'failed request leaves checkbox unchanged and shows server message',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: TaskSubtasks(
                taskId: '12',
                subtasks: subtasks,
                onChanged: (_, _) async {
                  throw const TaskRequestException(
                    'Вы не автор и не исполнитель задачи',
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.textContaining('Подзадачи ·'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(find.text('Вы не автор и не исполнитель задачи'), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox)).onChanged,
        isNotNull,
      );
    },
  );

  testWidgets('pending request disables repeated checkbox updates', (
    tester,
  ) async {
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: TaskSubtasks(
              taskId: '12',
              subtasks: subtasks,
              onChanged: (_, _) {
                calls++;
                return completer.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.textContaining('Подзадачи ·'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(calls, 1);
    completer.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNotNull);
  });
}
