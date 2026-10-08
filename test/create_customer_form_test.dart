import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/customers/models/create_customer.dart';
import 'package:crm_interface/modules/customers/repos/customers_repository.dart';
import 'package:crm_interface/modules/customers/widgets/create_customer.dart';
import 'package:crm_interface/modules/customers/widgets/entity_panel.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const options = CustomerCreationOptions(
  sources: [CustomerFormOption(id: 8, name: 'Рекомендация')],
  branches: [CustomerFormOption(id: 3, name: 'Центр')],
  employees: [CustomerFormOption(id: 12, name: 'Тестовый сотрудник')],
);

CreatedCustomerResponse result() => CreatedCustomerResponse(
  id: 42,
  fullName: 'Тестовый клиент',
  status: 'active',
  createdAt: DateTime.utc(2026, 10, 7),
);

Future<void> openForm(
  WidgetTester tester,
  Future<CreatedCustomerResponse> Function(CreateCustomerRequest) onCreate, {
  Future<CustomerCreationOptions> Function()? loadOptions,
}) async {
  tester.view.physicalSize = const Size(1100, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<CreatedCustomerResponse>(
              context: context,
              barrierDismissible: false,
              builder: (_) => CreateCustomerWindow(
                loadOptions: loadOptions ?? () async => options,
                onCreate: onCreate,
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

Future<void> selectOption(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> fillForm(WidgetTester tester, {bool emailOnly = false}) async {
  await tester.enterText(
    find.byKey(const Key('customer-name')),
    '  Тестовый клиент  ',
  );
  await tester.enterText(
    find.byKey(const Key('customer-birthday')),
    '15.03.1992',
  );
  await tester.enterText(
    find.byKey(Key(emailOnly ? 'customer-email' : 'customer-phone')),
    emailOnly ? ' client@example.com ' : ' +7 916 233-10-45 ',
  );
  await selectOption(tester, 'customer-source', 'Рекомендация');
}

void main() {
  testWidgets(
    'list plus opens creation and refreshes exactly once after success',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = ApiClient(SessionStore());
      addTearDown(() => client.dio.close(force: true));
      var created = false;
      var listRequests = 0;
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (request, handler) {
            dynamic data;
            if (request.method == 'POST') {
              expect(request.path, '/customers');
              created = true;
              data = {
                'id': 42,
                'full_name': 'Тестовый клиент',
                'status': 'active',
                'created_at': '2026-10-07T12:00:00Z',
              };
            } else if (request.path == '/customers') {
              listRequests++;
              data = {
                'items': [
                  if (created)
                    {
                      'id': 42,
                      'full_name': 'Тестовый клиент',
                      'gender': null,
                      'date_of_birth': '1992-03-15',
                      'status': 'active',
                      'primary_contact': '+79162331045',
                      'acquisition_source_name': 'Рекомендация',
                    },
                ],
              };
            } else if (request.path == '/acquisition-sources') {
              data = [
                {'id': 8, 'name': 'Рекомендация'},
              ];
            } else {
              expect(['/branches', '/employees'], contains(request.path));
              data = <dynamic>[];
            }
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: request.method == 'POST' ? 201 : 200,
                data: data,
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: EntityPanel(apiClient: client, onCustomerSelected: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(listRequests, 1);
      expect(find.text('Клиентов не найдено'), findsOneWidget);
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      await fillForm(tester);
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(listRequests, 2);
      expect(find.byType(CreateCustomerWindow), findsNothing);
      expect(find.text('Тестовый клиент'), findsOneWidget);
      expect(find.text('Клиент создан'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('validates required data and calendar dates before POST', (
    tester,
  ) async {
    var calls = 0;
    await openForm(tester, (_) async {
      calls++;
      return result();
    });
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(find.text('Введите ФИО'), findsOneWidget);
    expect(find.text('Укажите телефон или email'), findsOneWidget);
    expect(find.text('Выберите источник привлечения'), findsOneWidget);
    expect(calls, 0);

    await fillForm(tester);
    await tester.enterText(
      find.byKey(const Key('customer-birthday')),
      '31.02.2000',
    );
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(find.text('Укажите дату в формате дд.мм.гггг'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(
      find.byKey(const Key('customer-birthday')),
      '01.01.2999',
    );
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(find.text('Дата рождения не может быть в будущем'), findsOneWidget);
  });

  testWidgets('creates email-only customer without inventing optional IDs', (
    tester,
  ) async {
    CreateCustomerRequest? submitted;
    await openForm(tester, (request) async {
      submitted = request;
      return result();
    });
    await fillForm(tester, emailOnly: true);
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(submitted!.toApi(), {
      'full_name': 'Тестовый клиент',
      'date_of_birth': '1992-03-15',
      'acquisition_source_id': 8,
      'contacts': [
        {'type': 'email', 'value': 'client@example.com', 'is_primary': true},
      ],
    });
    expect(find.byType(CreateCustomerWindow), findsNothing);
  });

  testWidgets(
    'sends selected branch/employee and preserves input after conflict',
    (tester) async {
      var calls = 0;
      CreateCustomerRequest? submitted;
      await openForm(tester, (request) async {
        submitted = request;
        calls++;
        if (calls == 1) {
          throw const CustomerRequestException('Телефон уже занят');
        }
        return result();
      });
      await fillForm(tester);
      await selectOption(tester, 'customer-branch', 'Центр');
      await selectOption(tester, 'customer-employee', 'Тестовый сотрудник');
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(find.text('Телефон уже занят'), findsOneWidget);
      expect(submitted!.homeBranchId, 3);
      expect(submitted!.responsibleEmployeeId, 12);
      expect(find.text('15.03.1992'), findsOneWidget);
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(submitted!.fullName, 'Тестовый клиент');
      expect(find.byType(CreateCustomerWindow), findsNothing);
    },
  );

  testWidgets('blocks repeat submission and dismissal while saving', (
    tester,
  ) async {
    final pending = Completer<CreatedCustomerResponse>();
    var calls = 0;
    await openForm(tester, (_) {
      calls++;
      return pending.future;
    });
    await fillForm(tester);
    await tester.tap(find.text('Создать'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.widget<PopScope>(find.byType(PopScope).last).canPop, isFalse);
    expect(calls, 1);
    pending.complete(result());
    await tester.pumpAndSettle();
    expect(find.byType(CreateCustomerWindow), findsNothing);
  });

  testWidgets(
    'catalog failure supports retry and empty sources block creation',
    (tester) async {
      var loads = 0;
      await openForm(
        tester,
        (_) async => result(),
        loadOptions: () async {
          loads++;
          if (loads == 1) {
            throw const CustomerRequestException('Сервер недоступен');
          }
          return const CustomerCreationOptions(
            sources: [],
            branches: [],
            employees: [],
          );
        },
      );
      expect(find.text('Сервер недоступен'), findsOneWidget);
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(loads, 2);
      expect(find.textContaining('Нет доступных источников'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateCustomerWindow), findsNothing);
    },
  );
}
