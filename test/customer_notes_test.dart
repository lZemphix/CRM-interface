import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:crm_interface/modules/customers/models/customer_note.dart';
import 'package:crm_interface/modules/customers/repos/customers_repository.dart';
import 'package:crm_interface/modules/customers/widgets/customer_details/detail_panel.dart';
import 'package:crm_interface/modules/customers/widgets/customer_details/tabs/notes_tab.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> noteJson({
  int id = 1,
  String text = 'Исходная заметка',
  int version = 3,
}) => {
  'id': id,
  'author_employee_id': 9,
  'author': {'id': 9, 'full_name': 'Тестовый сотрудник'},
  'text': text,
  'created_at': '2026-10-08T06:00:00Z',
  'edited_at': null,
  'version': version,
};

Map<String, dynamic> detailsJson(int id, List<Map<String, dynamic>> notes) => {
  'id': id,
  'full_name': 'Тестовый Клиент',
  'status': 'active',
  'acquisition_source_id': 1,
  'acquisition_source_code': 'website',
  'acquisition_source_name': 'Сайт',
  'registration_method': 'employee',
  'created_at': '2026-10-07T12:00:00Z',
  'updated_at': '2026-10-08T06:00:00Z',
  'contacts': [],
  'notes': notes,
};

ApiClient makeClient() {
  final client = ApiClient(SessionStore());
  addTearDown(() => client.dio.close(force: true));
  return client;
}

class NotesRepository extends CustomersRepository {
  NotesRepository(super.client);
  List<CustomerNote> notes = [];
  CustomerRequestException? failure;
  int creates = 0;
  int archives = 0;
  int loads = 0;
  UpdateCustomerNoteRequest? update;
  Completer<CustomerNote>? pendingSave;
  Completer<List<CustomerNote>>? pendingLoad;

  @override
  Future<List<CustomerNote>> getCustomerNotes(int customerId) async {
    loads++;
    if (failure != null) throw failure!;
    return pendingLoad?.future ?? List.of(notes);
  }

  @override
  Future<CustomerNote> createNote(
    int customerId,
    CreateCustomerNoteRequest request,
  ) async {
    creates++;
    if (failure != null) throw failure!;
    return pendingSave?.future ??
        CustomerNote.fromJson(noteJson(id: 2, text: request.text));
  }

  @override
  Future<CustomerNote> updateNote(
    int customerId,
    int noteId,
    UpdateCustomerNoteRequest request,
  ) async {
    update = request;
    if (failure != null) throw failure!;
    return CustomerNote.fromJson({
      ...noteJson(id: noteId, text: request.text, version: request.version + 1),
      'edited_at': '2026-10-08T07:00:00Z',
    });
  }

  @override
  Future<void> archiveNote(int customerId, int noteId) async {
    archives++;
    if (failure != null) throw failure!;
  }
}

Future<void> mountNotes(
  WidgetTester tester,
  NotesRepository repo, {
  int customerId = 7,
  ValueChanged<List<CustomerNote>>? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CustomerNotesPanel(
          customerId: customerId,
          initialNotes: repo.notes,
          repository: repo,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openEditor(WidgetTester tester) async {
  await tester.tap(find.text('Добавить заметку'));
  await tester.pumpAndSettle();
}

Future<void> menu(WidgetTester tester, String action) async {
  await tester.tap(find.byTooltip('Действия с заметкой').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'parses typed customer notes, author, UTC dates and nullable edit date',
    () {
      final details = CustomerDetails.fromJson(detailsJson(7, [noteJson()]));
      expect(details.notes.single.authorEmployeeId, 9);
      expect(details.notes.single.authorName, 'Тестовый сотрудник');
      expect(details.notes.single.createdAt, DateTime.utc(2026, 10, 8, 6));
      expect(details.notes.single.editedAt, isNull);
      expect(details.notes.single.version, 3);
      expect(CustomerDetails.fromJson(detailsJson(8, [])).notes, isEmpty);
    },
  );

  test('repository uses actual GET/POST/PATCH/DELETE contracts', () async {
    final client = makeClient();
    final seen = <String>[];
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (request, handler) {
          seen.add('${request.method} ${request.path}');
          expect(request.queryParameters, isEmpty);
          if (request.method == 'GET') {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: detailsJson(7, [noteJson()]),
              ),
            );
          } else if (request.method == 'POST') {
            expect(request.data, {'text': 'Новая'});
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 201,
                data: noteJson(id: 2, text: 'Новая'),
              ),
            );
          } else if (request.method == 'PATCH') {
            expect(request.data, {'text': 'Правка', 'version': 3});
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: noteJson(text: 'Правка', version: 4),
              ),
            );
          } else {
            expect(request.data, isNull);
            handler.resolve(Response(requestOptions: request, statusCode: 204));
          }
        },
      ),
    );
    final repo = CustomersRepository(client);
    expect((await repo.getCustomerNotes(7)).single.id, 1);
    expect(
      (await repo.createNote(
        7,
        const CreateCustomerNoteRequest(text: ' Новая '),
      )).id,
      2,
    );
    expect(
      (await repo.updateNote(
        7,
        1,
        const UpdateCustomerNoteRequest(text: ' Правка ', version: 3),
      )).version,
      4,
    );
    await repo.archiveNote(7, 1);
    expect(seen, [
      'GET /customers/7',
      'POST /customers/7/notes',
      'PATCH /customers/7/notes/1',
      'DELETE /customers/7/notes/1',
    ]);
  });

  for (final status in [403, 404, 409, 422, 500]) {
    test('note mutation $status maps errors and refresh policy', () async {
      final client = makeClient();
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: request,
                  statusCode: status,
                  data: {
                    'detail': {'message': 'Ошибка заметки'},
                  },
                ),
              ),
            );
          },
        ),
      );
      await expectLater(
        CustomersRepository(client)
            .createNote(7, const CreateCustomerNoteRequest(text: 'Текст')),
        throwsA(
          isA<CustomerRequestException>().having(
            (e) => e.refreshRequired,
            'refresh',
            [404, 409, 500].contains(status),
          ),
        ),
      );
    });
  }

  test(
    'malformed success and unexpected archive status are not accepted',
    () async {
      final client = makeClient();
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: request.method == 'DELETE' ? 200 : 201,
                data: {'id': 2},
              ),
            );
          },
        ),
      );
      final repo = CustomersRepository(client);
      final uncertain = throwsA(
        isA<CustomerRequestException>().having(
          (e) => e.refreshRequired,
          'refresh',
          true,
        ),
      );
      await expectLater(
        repo.createNote(7, const CreateCustomerNoteRequest(text: 'Текст')),
        uncertain,
      );
      await expectLater(repo.archiveNote(7, 2), uncertain);
    },
  );

  testWidgets('empty state, validation, create and server-author display', (
    tester,
  ) async {
    final repo = NotesRepository(makeClient());
    List<CustomerNote>? published;
    await mountNotes(tester, repo, onChanged: (notes) => published = notes);
    expect(find.text('Пока нет заметок'), findsOneWidget);
    expect(repo.loads, 0);
    await openEditor(tester);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Введите текст заметки'), findsOneWidget);
    expect(repo.creates, 0);
    await tester.enterText(
      find.byKey(const ValueKey('customer-note-text')),
      '  Важный текст  ',
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Важный текст'), findsOneWidget);
    expect(find.text('Тестовый сотрудник'), findsOneWidget);
    expect(published!.single.id, 2);
  });

  testWidgets(
    'edit sends original version and displays canonical text/edit date',
    (tester) async {
      final repo = NotesRepository(makeClient())
        ..notes = [CustomerNote.fromJson(noteJson())];
      await mountNotes(tester, repo);
      await menu(tester, 'Редактировать');
      await tester.enterText(
        find.byKey(const ValueKey('customer-note-text')),
        ' Исправлено ',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(repo.update!.version, 3);
      expect(repo.update!.text, 'Исправлено');
      expect(find.text('Исправлено'), findsOneWidget);
      expect(find.textContaining('Изменено'), findsOneWidget);
      expect(find.text('Исходная заметка'), findsNothing);
    },
  );

  testWidgets('permission denial preserves draft and original note', (
    tester,
  ) async {
    final repo = NotesRepository(makeClient())
      ..notes = [CustomerNote.fromJson(noteJson())]
      ..failure = const CustomerRequestException('Недостаточно прав');
    await mountNotes(tester, repo);
    await menu(tester, 'Редактировать');
    await tester.enterText(
      find.byKey(const ValueKey('customer-note-text')),
      'Черновик',
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Недостаточно прав'), findsOneWidget);
    expect(find.text('Черновик'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Исходная заметка'), findsOneWidget);
  });

  testWidgets(
    'conflict blocks stale retry and explicit refresh gets new version',
    (tester) async {
      final repo = NotesRepository(makeClient())
        ..notes = [CustomerNote.fromJson(noteJson())]
        ..failure = const CustomerRequestException(
          'Заметка изменена',
          refreshRequired: true,
        );
      await mountNotes(tester, repo);
      await menu(tester, 'Редактировать');
      await tester.enterText(
        find.byKey(const ValueKey('customer-note-text')),
        'Черновик',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Сохранить'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Черновик'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      repo.failure = null;
      repo.notes = [
        CustomerNote.fromJson(noteJson(text: 'Чужая правка', version: 5)),
      ];
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Добавить заметку'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Обновить заметки'));
      await tester.pumpAndSettle();
      await menu(tester, 'Редактировать');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(repo.update!.version, 5);
      expect(find.text('Чужая правка'), findsOneWidget);
    },
  );

  testWidgets('archive cancel, denied and confirmed responses', (tester) async {
    final repo = NotesRepository(makeClient())
      ..notes = [CustomerNote.fromJson(noteJson())];
    await mountNotes(tester, repo);
    await menu(tester, 'Архивировать');
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(repo.archives, 0);
    repo.failure = const CustomerRequestException('Нельзя архивировать');
    await menu(tester, 'Архивировать');
    await tester.tap(find.widgetWithText(FilledButton, 'Архивировать'));
    await tester.pumpAndSettle();
    expect(find.text('Нельзя архивировать'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Исходная заметка'), findsOneWidget);
    repo.failure = null;
    await menu(tester, 'Архивировать');
    await tester.tap(find.widgetWithText(FilledButton, 'Архивировать'));
    await tester.pumpAndSettle();
    expect(find.text('Пока нет заметок'), findsOneWidget);
  });

  testWidgets('pending save disables duplicate actions and back navigation', (
    tester,
  ) async {
    final repo = NotesRepository(makeClient())
      ..pendingSave = Completer<CustomerNote>();
    await mountNotes(tester, repo);
    await openEditor(tester);
    await tester.enterText(
      find.byKey(const ValueKey('customer-note-text')),
      'Ожидаем',
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Сохранение…'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Отмена'))
          .onPressed,
      isNull,
    );
    expect(repo.creates, 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Новая заметка'), findsOneWidget);
    repo.pendingSave!.complete(
      CustomerNote.fromJson(noteJson(id: 2, text: 'Подтверждено')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Подтверждено'), findsOneWidget);
  });

  testWidgets(
    'refresh failure supports retry; stale result cannot replace another customer',
    (tester) async {
      final repo = NotesRepository(makeClient())
        ..failure = const CustomerRequestException('Сервер недоступен');
      await mountNotes(tester, repo);
      await tester.tap(find.byTooltip('Обновить заметки'));
      await tester.pumpAndSettle();
      expect(find.text('Сервер недоступен'), findsOneWidget);
      repo.failure = null;
      repo.pendingLoad = Completer<List<CustomerNote>>();
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      repo.notes = [
        CustomerNote.fromJson(noteJson(id: 8, text: 'Другой клиент')),
      ];
      await mountNotes(tester, repo, customerId: 8);
      repo.pendingLoad!.complete([
        CustomerNote.fromJson(noteJson(text: 'Старый ответ')),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Другой клиент'), findsOneWidget);
      expect(find.text('Старый ответ'), findsNothing);
    },
  );

  testWidgets(
    'parent retains mutations across tabs and resets on customer change',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = makeClient();
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (request, handler) {
            dynamic data;
            var status = 200;
            if (request.method == 'POST') {
              status = 201;
              data = noteJson(id: 2, text: 'Сохранённая заметка');
            } else if (request.path == '/customers/7') {
              data = detailsJson(7, []);
            } else if (request.path == '/customers/8') {
              data = detailsJson(8, [noteJson(id: 8, text: 'Другой клиент')]);
            } else if (request.path == '/tasks') {
              data = {'items': [], 'total': 0, 'limit': 50, 'offset': 0};
            } else if (request.path.endsWith('/activity')) {
              data = {'items': [], 'total': 0, 'limit': 20, 'offset': 0};
            } else {
              data = <dynamic>[];
            }
            handler.resolve(
              Response(requestOptions: request, statusCode: status, data: data),
            );
          },
        ),
      );
      Widget app(int id) => MaterialApp(
        home: Scaffold(
          body: DetailPanel(
            customer: Customer(
              id: id,
              fullName: 'Тестовый Клиент',
              status: 'active',
              acquisitionSourceName: 'Сайт',
            ),
            apiClient: client,
          ),
        ),
      );
      await tester.pumpWidget(app(7));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Заметки').first);
      await tester.pumpAndSettle();
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('customer-note-text')),
        'Сохранённая заметка',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('История').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Обзор').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Заметки').first);
      await tester.pumpAndSettle();
      expect(find.text('Сохранённая заметка'), findsOneWidget);
      await tester.pumpWidget(app(8));
      await tester.pumpAndSettle();
      if (find.text('Другой клиент').evaluate().isEmpty) {
        await tester.tap(find.text('Заметки').first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Другой клиент'), findsOneWidget);
      expect(find.text('Сохранённая заметка'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
