import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:crm_interface/modules/customers/widgets/entity_panel.dart';
import 'package:crm_interface/modules/customers/widgets/customer_identity.dart';
import 'package:crm_interface/modules/customers/widgets/customer_details/detail_panel.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> detailJson(
  int id, {
  String responsible = 'Ирина Ответственная',
}) => {
  'id': id,
  'full_name': 'Анна',
  'status': 'active',
  'home_branch_id': 3,
  'responsible_employee_id': 4,
  'responsible': {'id': 4, 'full_name': responsible},
  'created_by_employee_id': 5,
  'created_by': {'id': 5, 'full_name': 'Олег Создавший'},
  'acquisition_source_id': 1,
  'acquisition_source_code': 'site',
  'acquisition_source_name': 'Сайт',
  'registration_method': 'employee',
  'created_at': '2026-10-01T09:00:00Z',
  'updated_at': '2026-10-08T09:00:00Z',
  'notes': [],
  'contacts': [
    {
      'id': 1,
      'type': 'phone',
      'value': ' +79990000001 ',
      'is_primary': true,
      'created_at': '2026-10-01T09:00:00Z',
      'label': null,
    },
  ],
};

Map<String, dynamic> activityJson(int id) => {
  'id': id,
  'type': 'task.created',
  'occurred_at': '2026-10-08T09:00:00Z',
  'actor': null,
  'entity': {'id': id, 'type': 'task'},
  'data': {'title': 'Событие $id', 'status': 'new'},
};

class CardApi {
  CardApi() {
    addTearDown(() => client.dio.close(force: true));
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          requests.add(request.path);
          if (request.path == '/branches') {
            if (branchFailure) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.badResponse,
                  response: Response(requestOptions: request, statusCode: 403),
                ),
              );
              return;
            }
            final data =
                await (branches?.future ??
                    Future.value([
                      {'id': 3, 'name': 'Центральный'},
                    ]));
            handler.resolve(
              Response(requestOptions: request, statusCode: 200, data: data),
            );
            return;
          }
          final dynamic data;
          if (request.path == '/customers') {
            data = {
              'items': [
                {
                  'id': 1,
                  'full_name': 'Анна',
                  'status': 'active',
                  'primary_contact': ' +79990000001 ',
                  'acquisition_source_name': 'Сайт',
                  'responsible': {'id': 4, 'full_name': responsible},
                },
              ],
              'total': 1,
              'limit': 50,
              'offset': 0,
            };
          } else if (request.path == '/customers/1') {
            data = detailJson(1, responsible: responsible);
          } else if (request.path.endsWith('/activity')) {
            if (activityFailure) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.badResponse,
                  response: Response(requestOptions: request, statusCode: 503),
                ),
              );
              return;
            }
            final limit = request.queryParameters['limit'] as int;
            data = {
              'items': [
                if (!emptyActivity)
                  for (var id = 1; id <= limit; id++) activityJson(id),
              ],
              'total': 30,
              'limit': limit,
              'offset': 0,
            };
          } else if (request.path == '/tasks') {
            data = {'items': [], 'total': 0, 'limit': 20, 'offset': 0};
          } else {
            throw StateError('Unexpected ${request.path}');
          }
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: data),
          );
        },
      ),
    );
  }
  final client = ApiClient(SessionStore());
  final requests = <String>[];
  bool branchFailure = false;
  bool activityFailure = false;
  bool emptyActivity = false;
  Completer<List<Map<String, dynamic>>>? branches;
  String responsible = 'Ирина Ответственная';
}

Future<void> mountDetail(
  WidgetTester tester,
  CardApi api, {
  double width = 1400,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DetailPanel(
          customer: const Customer(
            id: 1,
            fullName: 'Анна',
            status: 'active',
            acquisitionSourceName: 'Сайт',
          ),
          apiClient: api.client,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'recent activity failure is not reported as an empty history and can retry',
    (tester) async {
      final api = CardApi()..activityFailure = true;
      await mountDetail(tester, api);
      await tester.pumpAndSettle();
      expect(find.text('Ошибка сервера. Попробуйте позже.'), findsOneWidget);
      expect(find.text('Событий пока нет'), findsNothing);
      api.activityFailure = false;
      api.emptyActivity = true;
      await tester.tap(find.byTooltip('Обновить последнюю активность'));
      await tester.pumpAndSettle();
      expect(find.text('Событий пока нет'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('initials support single/empty names, extra whitespace and Unicode', () {
    expect(customerNameIcon('Анна'), 'А');
    expect(customerNameIcon('  Анна   Петрова Сергеевна  '), 'АП');
    expect(customerNameIcon(''), '?');
    expect(customerNameIcon('👩‍💻 Разработчик'), '👩‍💻Р');
    expect(getPrimaryContact([]), 'Контакт не указан');
  });

  testWidgets(
    'small cards use the employee name without fake branch/visit placeholders',
    (tester) async {
      final api = CardApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: EntityPanel(
                apiClient: api.client,
                onCustomerSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ирина Ответственная'), findsOneWidget);
      expect(find.text('+79990000001'), findsOneWidget);
      expect(find.textContaining('н/д'), findsNothing);
      expect(find.text('Нет'), findsNothing);
      expect(find.text('Нет визитов'), findsNothing);
      expect(api.requests, ['/customers']);
      api.responsible = 'Другой Ответственный';
      await tester.tap(find.byTooltip('Обновить список клиентов'));
      await tester.pumpAndSettle();
      expect(find.text('Другой Ответственный'), findsOneWidget);
      expect(find.text('Ирина Ответственная'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detail shows actual employees, branch, dates and last three events',
    (tester) async {
      final api = CardApi();
      await mountDetail(tester, api);
      await tester.pumpAndSettle();
      expect(find.text('Ирина Ответственная'), findsOneWidget);
      expect(find.text('Олег Создавший'), findsOneWidget);
      expect(find.text('Центральный'), findsNWidgets(2));
      expect(find.text('В системе с'), findsOneWidget);
      expect(find.text('Карточка обновлена'), findsOneWidget);
      expect(find.textContaining('Нет данных'), findsNothing);
      expect(find.textContaining('н/д'), findsNothing);
      expect(find.text('Последний контакт'), findsNothing);
      expect(find.text('Событие 1'), findsOneWidget);
      expect(find.text('Событие 3'), findsOneWidget);
      expect(find.text('Событие 4'), findsNothing);
      expect(api.requests.where((path) => path == '/employees'), isEmpty);
      expect(tester.takeException(), isNull);
      api.responsible = 'Новый Ответственный';
      await tester.tap(find.byTooltip('Обновить карточку клиента'));
      await tester.pumpAndSettle();
      expect(find.text('Новый Ответственный'), findsOneWidget);
      expect(find.text('Ирина Ответственная'), findsNothing);
    },
  );

  testWidgets('branch lookup failure does not block customer details', (
    tester,
  ) async {
    final api = CardApi()..branchFailure = true;
    await mountDetail(tester, api);
    await tester.pumpAndSettle();
    expect(find.text('Ирина Ответственная'), findsOneWidget);
    expect(find.text('Филиал #3 (название недоступно)'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'late branch dictionary fills the name without blocking the card',
    (tester) async {
      final api = CardApi()..branches = Completer<List<Map<String, dynamic>>>();
      await mountDetail(tester, api);
      await tester.pumpAndSettle();
      expect(find.text('Ирина Ответственная'), findsOneWidget);
      expect(find.text('Филиал #3'), findsNWidgets(2));
      api.branches!.complete([
        {'id': 3, 'name': 'Западный'},
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Западный'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow panel scrolls without layout overflow', (tester) async {
    final api = CardApi();
    await mountDetail(tester, api, width: 380);
    await tester.pumpAndSettle();
    expect(find.text('Ирина Ответственная'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
