import 'package:crm_interface/modules/tasks/widgets/task_column_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty column has a counter and hint', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 184,
              child: TaskColumnHeader(title: 'Новые', taskCount: 0),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Новые'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Перетащите задачу сюда'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long title does not push the counter outside the column', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 184,
              child: TaskColumnHeader(
                title: 'Очень длинное название колонки ' * 5,
                taskCount: 123,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('123'), findsOneWidget);
    expect(find.text('Перетащите задачу сюда'), findsNothing);
    final title = tester.widget<Text>(
      find.text('Очень длинное название колонки ' * 5),
    );
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.maxLines, 1);
    expect(tester.takeException(), isNull);
  });
}
