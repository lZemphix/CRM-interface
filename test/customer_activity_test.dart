import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/customers/models/customer_activity.dart';
import 'package:crm_interface/modules/customers/repos/customers_repository.dart';
import 'package:crm_interface/modules/customers/widgets/customer_details/tabs/activity_tab.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_interface/core/widgets/section_refresh_controller.dart';

import 'support/section_refresh.dart';

Map<String, dynamic> activityJson({
  int id = 1,
  String type = 'task.status_changed',
  Map<String, dynamic>? data,
}) => {
  'id': id,
  'type': type,
  'occurred_at': '2026-10-08T10:00:00Z',
  'actor': null,
  'entity': {'type': type.split('.').first, 'id': 7},
  'data':
      data ??
      {
        'title': 'Позвонить клиенту',
        'from_status': 'new',
        'to_status': 'in_progress',
        'reason': null,
      },
};

ApiClient makeClient() {
  final client = ApiClient(SessionStore());
  addTearDown(() => client.dio.close(force: true));
  return client;
}

class ActivityRepository extends CustomersRepository {
  ActivityRepository() : super(makeClient()) {
    addTearDown(refresh.dispose);
  }
  final refresh = SectionRefreshController();
  final requests = <({int customer, int offset, CustomerActivityType? type})>[];
  CustomerRequestException? failure;
  Completer<CustomerActivityPage>? pending;
  int total = 25;

  @override
  Future<CustomerActivityPage> getActivity(
    int customerId, {
    int limit = 20,
    int offset = 0,
    CustomerActivityType? type,
  }) async {
    requests.add((customer: customerId, offset: offset, type: type));
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    return CustomerActivityPage(
      items: total == 0
          ? []
          : [
              CustomerActivity.fromApi(
                activityJson(
                  id: offset + 1,
                  type: type?.apiValue ?? 'task.status_changed',
                  data: type == CustomerActivityType.noteCreated
                      ? {}
                      : {
                          'title': 'Клиент $customerId',
                          'from_status': 'new',
                          'to_status': 'in_progress',
                        },
                ),
              ),
            ],
      total: total,
      limit: limit,
      offset: offset,
    );
  }
}

Future<void> mount(
  WidgetTester tester,
  ActivityRepository repository, {
  int customerId = 7,
  int reloadToken = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(actions: [sectionRefreshButton(repository.refresh)]),
        body: CustomerActivityPanel(
          refreshController: repository.refresh,
          customerId: customerId,
          repository: repository,
          reloadToken: reloadToken,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'activity filter stays compact on the left and can reset to all',
    (tester) async {
      final repo = ActivityRepository();
      await mount(tester, repo);
      await tester.pumpAndSettle();
      final filter = find.byType(DropdownButtonFormField<CustomerActivityType>);
      expect(tester.getSize(filter).width, 250);
      expect(tester.getTopLeft(filter).dx, 23); // Padding + panel border.
      expect(tester.getSize(filter).height, lessThanOrEqualTo(48));
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ответственный задачи'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Ответственный задачи').last);
      await tester.pumpAndSettle();
      expect(
        repo.requests.last.type,
        CustomerActivityType.taskResponsibleChanged,
      );
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Все события'),
        -100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Все события').last);
      await tester.pumpAndSettle();
      expect(repo.requests.last.type, isNull);
      expect(repo.requests.last.offset, 0);
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(tester.getSize(filter).width, lessThanOrEqualTo(250));
      expect(tester.takeException(), isNull);
    },
  );

  test('parses nullable actor and employee references and empty note data', () {
    final responsible = CustomerActivity.fromApi(
      activityJson(
        type: 'customer.responsible_changed',
        data: {
          'from_employee': null,
          'to_employee': {'id': 9, 'full_name': 'Сотрудник'},
        },
      ),
    );
    expect(responsible.actor, isNull);
    expect(responsible.data.fromEmployee, isNull);
    expect(responsible.data.toEmployee!.id, 9);
    expect(responsible.occurredAt.isUtc, isTrue);
    for (final type in ['note.created', 'note.updated', 'note.archived']) {
      final note = CustomerActivity.fromApi(activityJson(type: type, data: {}));
      expect(note.data.title, isNull);
      expect(note.type, isNotNull);
    }
  });

  test('GET activity sends pagination and exact event filter', () async {
    final client = makeClient();
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (request, handler) {
          expect(request.path, '/customers/7/activity');
          expect(request.method, 'GET');
          expect(request.queryParameters, {
            'limit': 20,
            'offset': 20,
            'type': 'note.created',
          });
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'items': [activityJson(type: 'note.created', data: {})],
                'total': 21,
                'limit': 20,
                'offset': 20,
              },
            ),
          );
        },
      ),
    );
    final page = await CustomersRepository(client)
        .getActivity(7, offset: 20, type: CustomerActivityType.noteCreated);
    expect(page.items.single.type, CustomerActivityType.noteCreated);
    expect(page.total, 21);
  });

  for (final status in [403, 404, 500]) {
    test('activity converts HTTP $status without leaking internals', () async {
      final client = makeClient();
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.reject(
            DioException(
              requestOptions: request,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: request,
                statusCode: status,
                data: {
                  'detail': {
                    'message': status == 500
                        ? 'Secret traceback'
                        : 'Клиент не найден',
                  },
                },
              ),
            ),
          ),
        ),
      );
      await expectLater(
        CustomersRepository(client).getActivity(7),
        throwsA(
          isA<CustomerRequestException>().having(
            (error) => error.message,
            'safe message',
            status == 403
                ? 'Недостаточно прав для этого действия'
                : status == 404
                ? 'Клиент не найден'
                : 'Ошибка сервера. Попробуйте позже.',
          ),
        ),
      );
    });
  }

  test('invalid activity payload becomes a safe repository error', () async {
    final client = makeClient();
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.resolve(
          Response(
            requestOptions: request,
            statusCode: 200,
            data: {'items': null},
          ),
        ),
      ),
    );
    await expectLater(
      CustomersRepository(client).getActivity(7),
      throwsA(isA<CustomerRequestException>()),
    );
  });

  testWidgets('shows timeline, filters, pages and refresh resets offset', (
    tester,
  ) async {
    final repo = ActivityRepository();
    await mount(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Клиент 7'), findsOneWidget);
    expect(find.text('Новая → В работе'), findsOneWidget);
    expect(find.textContaining('Система / автор неизвестен'), findsOneWidget);
    await tester.tap(find.byTooltip('Следующие события'));
    await tester.pumpAndSettle();
    expect(repo.requests.last.offset, 20);
    await tester.tap(find.byTooltip('Обновить вкладку'));
    await tester.pumpAndSettle();
    expect(repo.requests.last.offset, 20);
    await tester.tap(
      find.byType(DropdownButtonFormField<CustomerActivityType>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавлена заметка').last);
    await tester.pumpAndSettle();
    expect(repo.requests.last.type, CustomerActivityType.noteCreated);
    expect(find.text('Добавлена заметка'), findsNWidgets(2));
    expect(find.text('Клиент 7'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty/error/retry and mutation reload are supported', (
    tester,
  ) async {
    final repo = ActivityRepository()
      ..failure = const CustomerRequestException('Сервер недоступен');
    await mount(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Сервер недоступен'), findsOneWidget);
    repo.failure = null;
    repo.total = 0;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Событий пока нет'), findsOneWidget);
    repo.total = 1;
    await mount(tester, repo, reloadToken: 1);
    await tester.pumpAndSettle();
    expect(find.text('Клиент 7'), findsOneWidget);
  });

  testWidgets(
    'late response cannot overwrite another customer or disposed widget',
    (tester) async {
      final repo = ActivityRepository()
        ..pending = Completer<CustomerActivityPage>();
      final old = repo.pending!;
      await mount(tester, repo);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.pending = null;
      await mount(tester, repo, customerId: 8);
      await tester.pumpAndSettle();
      old.complete(
        CustomerActivityPage(
          items: [
            CustomerActivity.fromApi(
              activityJson(data: {'title': 'Старый ответ'}),
            ),
          ],
          total: 1,
          limit: 20,
          offset: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Клиент 8'), findsOneWidget);
      expect(find.text('Старый ответ'), findsNothing);
      repo.pending = Completer<CustomerActivityPage>();
      await tester.tap(find.byTooltip('Обновить вкладку'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      repo.pending!.complete(
        const CustomerActivityPage(items: [], total: 0, limit: 20, offset: 0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown future events render without inventing their meaning', (
    tester,
  ) async {
    final event = CustomerActivity.fromApi(
      activityJson(type: 'customer.future_event', data: {}),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CustomerActivityTile(event: event)),
      ),
    );
    expect(find.text('Событие: customer.future_event'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
