import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:crm_interface/modules/customers/repos/customers_repository.dart';
import 'package:crm_interface/modules/customers/widgets/entity_panel.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> customerJson(int id, String name) => {
  'id': id,
  'full_name': name,
  'gender': null,
  'date_of_birth': null,
  'status': 'active',
  'primary_contact': '+79162331045',
  'acquisition_source_name': 'Сайт',
};

class SearchApi {
  SearchApi(this.load) {
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          expect(request.path, '/customers');
          final query = request.queryParameters['search'] as String?;
          queries.add(query);
          parameters.add(Map<String, dynamic>.from(request.queryParameters));
          if (fail) {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.badResponse,
                response: Response(requestOptions: request, statusCode: 503),
              ),
            );
            return;
          }
          final items = await load(query);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'items': items,
                'total': items.length,
                'limit': 50,
                'offset': 0,
              },
            ),
          );
        },
      ),
    );
  }

  final client = ApiClient(SessionStore());
  final Future<List<Map<String, dynamic>>> Function(String?) load;
  final List<String?> queries = [];
  final List<Map<String, dynamic>> parameters = [];
  bool fail = false;
}

Future<void> openPanel(
  WidgetTester tester,
  SearchApi api, {
  ValueChanged<Customer>? onSelected,
}) async {
  addTearDown(() => api.client.dio.close(force: true));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: EntityPanel(
            apiClient: api.client,
            onCustomerSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'debounces input and obtains matches from API rather than the current page',
    (tester) async {
      final api = SearchApi(
        (query) async => query == null
            ? [customerJson(1, 'Анна Петрова')]
            : [customerJson(61, 'Сергей Иванов')],
      );
      Customer? selected;
      await openPanel(
        tester,
        api,
        onSelected: (customer) => selected = customer,
      );
      final search = find.byKey(const Key('customer-list-search'));
      await tester.enterText(search, 'Ива');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.enterText(search, '  Иванов  ');
      await tester.pump(const Duration(milliseconds: 200));
      expect(api.queries, [null]);
      await tester.pump(const Duration(milliseconds: 110));
      await tester.pumpAndSettle();
      expect(api.queries, [null, 'Иванов']);
      expect(find.text('Анна Петрова'), findsNothing);
      expect(find.text('Сергей Иванов'), findsOneWidget);
      await tester.tap(find.text('Сергей Иванов'));
      await tester.pumpAndSettle();
      expect(selected!.id, 61);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an old response cannot replace newer results and clear restores the full list',
    (tester) async {
      final old = Completer<List<Map<String, dynamic>>>();
      final api = SearchApi((query) {
        if (query == 'старый') return old.future;
        return Future.value([
          customerJson(
            query == null ? 1 : 2,
            query == null ? 'Все клиенты' : 'Новый результат',
          ),
        ]);
      });
      await openPanel(tester, api);
      final search = find.byKey(const Key('customer-list-search'));
      await tester.enterText(search, 'старый');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.enterText(search, 'новый');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Новый результат'), findsOneWidget);
      old.complete([customerJson(3, 'Старый результат')]);
      await tester.pumpAndSettle();
      expect(find.text('Старый результат'), findsNothing);
      expect(find.text('Новый результат'), findsOneWidget);
      await tester.tap(find.byTooltip('Очистить поиск клиентов'));
      await tester.pumpAndSettle();
      expect(api.queries.last, isNull);
      expect(find.text('Все клиенты'), findsOneWidget);
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    },
  );

  testWidgets(
    'empty/error/retry retain the search; Enter sends immediately without a second timer request',
    (tester) async {
      final api = SearchApi((_) async => []);
      await openPanel(tester, api);
      final search = find.byKey(const Key('customer-list-search'));
      await tester.enterText(search, 'нет клиента');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(api.queries, [null, 'нет клиента']);
      expect(find.text('По запросу клиенты не найдены'), findsOneWidget);
      api.fail = true;
      await tester.enterText(search, 'проверка');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Ошибка сервера. Попробуйте позже.'), findsOneWidget);
      api.fail = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(api.queries.last, 'проверка');
      expect(tester.widget<TextField>(search).controller!.text, 'проверка');
    },
  );

  testWidgets('disposing the panel cancels a pending search', (tester) async {
    final api = SearchApi((_) async => []);
    await openPanel(tester, api);
    await tester.enterText(
      find.byKey(const Key('customer-list-search')),
      'запрос',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.queries, [null]);
    expect(tester.takeException(), isNull);
  });

  test('repository sends trimmed optional search with the original pagination contract', () async {
    final api = SearchApi((_) async => []);
    addTearDown(() => api.client.dio.close(force: true));
    final repository = CustomersRepository(api.client);
    await repository.getCustomers(search: '  +7 916  ', limit: 10, offset: 20);
    await repository.getCustomers(search: '   ');
    expect(api.queries, ['+7 916', null]);
    expect(api.parameters, [
      {'limit': 10, 'offset': 20, 'search': '+7 916'},
      {'limit': 50, 'offset': 0},
    ]);
  });
}
