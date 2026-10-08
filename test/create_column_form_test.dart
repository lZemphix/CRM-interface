import 'dart:async';

import 'package:crm_interface/modules/tasks/models/task_column.dart';
import 'package:crm_interface/modules/tasks/widgets/create_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openColumnForm(
  WidgetTester tester,
  Future<void> Function(CreateTaskColumnRequest) onCreate,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => CreateTaskColumnWindow(onCreate: onCreate),
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
  testWidgets('validates a column name and submits a trimmed DTO', (
    tester,
  ) async {
    CreateTaskColumnRequest? submitted;
    await openColumnForm(tester, (request) async => submitted = request);
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(find.text('Введите название колонки'), findsOneWidget);
    expect(submitted, isNull);

    await tester.enterText(find.byType(TextFormField), '  Ожидает ответа  ');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(submitted!.name, 'Ожидает ответа');
    expect(submitted!.status, isNull);
    expect(submitted!.toApi()['status'], isNull);
    expect(find.byType(CreateTaskColumnWindow), findsNothing);
  });

  testWidgets('sends the explicitly selected column status', (tester) async {
    CreateTaskColumnRequest? submitted;
    await openColumnForm(tester, (request) async => submitted = request);
    await tester.enterText(find.byType(TextFormField), 'Проверка результата');
    await tester.tap(find.byType(DropdownButtonFormField<TaskColumnStatus>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выполнена — на проверке').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(submitted!.toApi(), {
      'name': 'Проверка результата',
      'status': 'completed',
    });
  });

  testWidgets('can return from typed status to neutral', (tester) async {
    CreateTaskColumnRequest? submitted;
    await openColumnForm(tester, (request) async => submitted = request);
    await tester.enterText(find.byType(TextFormField), 'Свободная');
    await tester.tap(find.byType(DropdownButtonFormField<TaskColumnStatus>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В работе').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<TaskColumnStatus>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Без изменения статуса').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(submitted!.status, isNull);
  });

  testWidgets('keeps the name on failure and allows a retry', (tester) async {
    var attempts = 0;
    await openColumnForm(tester, (_) async {
      attempts++;
      if (attempts == 1) throw Exception('Network error');
    });
    await tester.enterText(find.byType(TextFormField), 'Проверка');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(
      find.text('Не удалось создать колонку. Попробуйте ещё раз.'),
      findsOneWidget,
    );
    expect(find.text('Проверка'), findsOneWidget);
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(CreateTaskColumnWindow), findsNothing);
  });

  testWidgets('blocks duplicate requests while saving', (tester) async {
    final completion = Completer<void>();
    var attempts = 0;
    await openColumnForm(tester, (_) {
      attempts++;
      return completion.future;
    });
    await tester.enterText(find.byType(TextFormField), 'В работе');
    await tester.tap(find.text('Создать'));
    await tester.pump();
    final submitButton = find.widgetWithText(FilledButton, 'Создаём…');
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNull);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Отмена'))
          .onPressed,
      isNull,
    );
    await tester.tap(submitButton);
    expect(attempts, 1);
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CreateTaskColumnWindow), findsNothing);
  });

  testWidgets('cancel closes the dialog without a request', (tester) async {
    var attempts = 0;
    await openColumnForm(tester, (_) async => attempts++);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(attempts, 0);
    expect(find.byType(CreateTaskColumnWindow), findsNothing);
  });
}
