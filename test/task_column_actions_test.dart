import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/repos/request_error.dart';
import 'package:crm_interface/modules/tasks/widgets/column_actions.dart';
import 'package:crm_interface/modules/tasks/widgets/task_column_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty neutral column can archive without a target', (
    tester,
  ) async {
    var called = false;
    String? target;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskColumnActionWindow(
            column: const TaskboardColumn(
              id: '9',
              name: 'Ожидание',
              order: 0,
              countsAsDone: false,
              status: null,
              version: 1,
            ),
            action: TaskColumnAction.archive,
            targets: [],
            canArchiveWithoutTarget: true,
            onRename: (_) async {},
            onArchive: (value) async {
              called = true;
              target = value;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Архивировать'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(target, isNull);
  });
  const column = TaskboardColumn(
    id: '1',
    name: 'Очередь',
    order: 0,
    countsAsDone: false,
    status: 'new',
    version: 1,
  );

  testWidgets('rename validation prevents empty requests', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskColumnActionWindow(
            column: column,
            action: TaskColumnAction.rename,
            targets: [],
            onRename: (_) async {
              called = true;
            },
            onArchive: (_) async {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(called, isFalse);
    expect(find.text('Введите название колонки'), findsOneWidget);
  });

  testWidgets('server failure preserves dialog and entered name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskColumnActionWindow(
            column: column,
            action: TaskColumnAction.rename,
            targets: [],
            onRename: (_) async =>
                throw const TaskRequestException('Недостаточно прав'),
            onArchive: (_) async {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'Мой заголовок');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Недостаточно прав'), findsOneWidget);
    expect(find.text('Мой заголовок'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Сохранить'))
          .onPressed,
      isNotNull,
    );
  });
}
