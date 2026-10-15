import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/customers/models/create_customer.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:crm_interface/modules/customers/models/update_customer.dart';
import 'package:crm_interface/modules/customers/repos/customers_repository.dart';
import 'package:crm_interface/modules/customers/screens/customers.dart';
import 'package:crm_interface/modules/customers/widgets/customer_details/contact_dialogs.dart';
import 'package:crm_interface/modules/customers/widgets/customer_details/edit_customer.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> contactJson({
  int id = 1,
  int version = 2,
  String value = '+79162331045',
  bool primary = true,
}) => {
  'id': id,
  'type': 'phone',
  'value': value,
  'label': null,
  'is_primary': primary,
  'created_at': '2026-10-01T09:00:00Z',
  'version': version,
};

Map<String, dynamic> detailJson() => {
  'id': 1,
  'full_name': 'Анна Петрова',
  'gender': 'female',
  'date_of_birth': '1992-03-15',
  'status': 'active',
  'version': 3,
  'home_branch_id': 4,
  'responsible_employee_id': 5,
  'responsible': {'id': 5, 'full_name': 'Ирина Ответственная'},
  'created_by_employee_id': 5,
  'created_by': {'id': 5, 'full_name': 'Ирина Ответственная'},
  'acquisition_source_id': 1,
  'acquisition_source_code': 'site',
  'acquisition_source_name': 'Сайт',
  'registration_method': 'employee',
  'referred_by_customer_id': null,
  'created_at': '2026-10-01T09:00:00Z',
  'updated_at': '2026-10-08T09:00:00Z',
  'notes': [],
  'contacts': [contactJson()],
};

const editOptions = CustomerEditOptions(
  branches: [CustomerFormOption(id: 4, name: 'Центральный')],
  employees: [CustomerFormOption(id: 5, name: 'Ирина Ответственная')],
);

class EditApi {
  EditApi() {
    addTearDown(() => client.dio.close(force: true));
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (r, h) async {
          requests.add(r);
          final mutation = r.method != 'GET';
          if (mutation && pending != null) await pending!.future;
          if (mutation && (failureStatus != null || timeout)) {
            h.reject(
              DioException(
                requestOptions: r,
                type: timeout
                    ? DioExceptionType.receiveTimeout
                    : DioExceptionType.badResponse,
                response: timeout
                    ? null
                    : Response(
                        requestOptions: r,
                        statusCode: failureStatus,
                        data: {
                          'detail': {
                            'code': errorCode,
                            'message': 'Отказ сервера',
                          },
                        },
                      ),
              ),
            );
            return;
          }
          if (r.method == 'GET' &&
              r.path == '/customers/1' &&
              failRefresh &&
              requests.any((item) => item.method != 'GET')) {
            h.reject(
              DioException(
                requestOptions: r,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          dynamic data;
          var status = 200;
          if (mutation && malformed) {
            data = {'id': 1};
          } else if (r.path == '/customers/1' && r.method == 'PATCH') {
            details.addAll(Map<String, dynamic>.from(r.data as Map));
            details['version'] = (details['version'] as int) + 1;
            data = {
              for (final key in [
                'id',
                'full_name',
                'gender',
                'date_of_birth',
                'status',
                'responsible_employee_id',
                'home_branch_id',
                'updated_at',
                'version',
              ])
                key: details[key],
            };
          } else if (r.path == '/customers/1/contacts' && r.method == 'POST') {
            final contacts = details['contacts'] as List;
            if (r.data['is_primary'] == true) {
              for (final contact in contacts) {
                if (contact['type'] == r.data['type']) {
                  contact['is_primary'] = false;
                  contact['version']++;
                }
              }
            }
            data = {
              ...contactJson(id: 2, version: 1),
              ...Map<String, dynamic>.from(r.data as Map),
            };
            contacts.add(data);
            status = 201;
          } else if (r.path == '/customers/1/contacts/1' &&
              r.method == 'PATCH') {
            final contact = (details['contacts'] as List).first as Map;
            contact.addAll(Map<String, dynamic>.from(r.data as Map));
            contact['version']++;
            data = Map<String, dynamic>.from(contact);
          } else if (r.path == '/customers/1/contacts/1' &&
              r.method == 'DELETE') {
            (details['contacts'] as List).removeWhere((c) => c['id'] == 1);
            status = 204;
          } else if (r.path == '/customers/1') {
            // A transport response is a snapshot, not a live reference to server state.
            data = {
              ...details,
              'contacts': [
                for (final c in details['contacts'] as List) {...c as Map},
              ],
            };
          } else if (r.path == '/customers') {
            data = {
              'items': [
                {
                  ...details,
                  'primary_contact': (details['contacts'] as List).isEmpty
                      ? null
                      : details['contacts'][0]['value'],
                },
              ],
              'total': 1,
              'limit': 50,
              'offset': 0,
            };
          } else if (r.path == '/branches') {
            data = [
              {'id': 4, 'name': 'Центральный'},
            ];
          } else if (r.path == '/employees') {
            data = [
              {'id': 5, 'full_name': 'Ирина Ответственная'},
            ];
          } else if (r.path == '/tasks' || r.path.endsWith('/activity')) {
            data = {'items': [], 'total': 0, 'limit': 20, 'offset': 0};
          } else {
            throw StateError('Unexpected ${r.method} ${r.path}');
          }
          h.resolve(
            Response(requestOptions: r, statusCode: status, data: data),
          );
        },
      ),
    );
  }
  final client = ApiClient(SessionStore());
  late final repository = CustomersRepository(client);
  final details = detailJson();
  final requests = <RequestOptions>[];
  int? failureStatus;
  String errorCode = 'version_conflict';
  bool timeout = false;
  bool malformed = false;
  bool failRefresh = false;
  Completer<void>? pending;
  Iterable<RequestOptions> get mutations =>
      requests.where((r) => r.method != 'GET');
}

Future<void> openDialog(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<Object?>(
              context: context,
              barrierDismissible: false,
              builder: (_) => dialog,
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

EditCustomerWindow editWindow(EditApi api, {VoidCallback? refreshRequired}) =>
    EditCustomerWindow(
      customer: CustomerDetails.fromJson(api.details),
      options: editOptions,
      onSave: (request) => api.repository.updateCustomer(1, request),
      onRefreshRequired: refreshRequired ?? () {},
    );

Future<void> saveName(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const Key('edit-customer-name')), name);
  await tester.tap(find.text('Сохранить'));
  await tester.pumpAndSettle();
}

void main() {
  test('PATCH distinguishes omitted fields and explicit null; birthday is a calendar date', () {
    final body = UpdateCustomerRequest(
      version: 7,
      fullName: 'Имя',
      gender: const CustomerFieldChange(null),
      homeBranchId: const CustomerFieldChange(null),
      dateOfBirth: DateTime(1992, 3, 15),
    ).toApi();
    expect(body, {
      'version': 7,
      'full_name': 'Имя',
      'gender': null,
      'home_branch_id': null,
      'date_of_birth': '1992-03-15',
    });
    expect(body.containsKey('responsible_employee_id'), isFalse);
    expect(body.containsKey('acquisition_source_id'), isFalse);
    expect(const UpdateCustomerRequest(version: 7).toApi(), {'version': 7});
  });

  test(
    'contact create includes type; PATCH uses version and never changes type',
    () {
      const request = WriteCustomerContactRequest(
        type: ContactType.email,
        value: 'test@example.org',
        label: null,
        isPrimary: true,
      );
      expect(request.toCreateApi()['type'], 'email');
      expect(request.toUpdateApi(version: 3), {
        'value': 'test@example.org',
        'label': null,
        'is_primary': true,
        'version': 3,
      });
    },
  );

  test('details and contacts read separate server versions; legacy GET is still readable', () {
    final json = detailJson();
    expect(CustomerDetails.fromJson(json).version, 3);
    expect(CustomerDetails.fromJson(json).contacts.single.version, 2);
    json.remove('version');
    expect(CustomerDetails.fromJson(json).version, isNull);
  });

  test(
    'repository sends PATCH JSON and parses the dedicated response',
    () async {
      final api = EditApi();
      final result = await api.repository.updateCustomer(
        1,
        const UpdateCustomerRequest(version: 3, fullName: 'Новое имя'),
      );
      expect(result.fullName, 'Новое имя');
      expect(result.version, 4);
      expect(api.mutations.single.path, '/customers/1');
      expect(api.mutations.single.queryParameters, isEmpty);
      expect(api.mutations.single.data, {
        'version': 3,
        'full_name': 'Новое имя',
      });
    },
  );

  test(
    'repository uses POST/PATCH/DELETE contacts contracts and typed responses',
    () async {
      final api = EditApi();
      const request = WriteCustomerContactRequest(
        type: ContactType.phone,
        value: '+79162331046',
        label: null,
        isPrimary: false,
      );
      expect((await api.repository.addContact(1, request)).id, 2);
      expect(
        (await api.repository.updateContact(1, 1, request, version: 2)).version,
        3,
      );
      await api.repository.archiveContact(1, 1);
      expect(api.mutations.map((r) => r.method), ['POST', 'PATCH', 'DELETE']);
      expect(api.mutations.elementAt(1).data.containsKey('type'), isFalse);
      expect(api.mutations.last.queryParameters, isEmpty);
    },
  );

  for (final scenario in [
    (409, 'version_conflict', true),
    (409, 'duplicate_primary_contact', false),
    (409, 'primary_contact_required', false),
    (403, 'forbidden', false),
    (422, 'invalid_contact', false),
    (500, 'internal', true),
  ]) {
    test(
      'mutation error ${scenario.$1}/${scenario.$2}: refresh=${scenario.$3}',
      () async {
        final api = EditApi()
          ..failureStatus = scenario.$1
          ..errorCode = scenario.$2;
        await expectLater(
          api.repository.updateCustomer(
            1,
            const UpdateCustomerRequest(version: 3, fullName: 'Имя'),
          ),
          throwsA(
            isA<CustomerRequestException>().having(
              (e) => e.refreshRequired,
              'refreshRequired',
              scenario.$3,
            ),
          ),
        );
      },
    );
  }

  test('timeout and malformed success block blind retry', () async {
    final api = EditApi()..timeout = true;
    Future<UpdatedCustomerResponse> save() => api.repository.updateCustomer(
      1,
      const UpdateCustomerRequest(version: 3, fullName: 'Имя'),
    );
    final uncertain = throwsA(
      isA<CustomerRequestException>().having(
        (e) => e.refreshRequired,
        'refresh',
        true,
      ),
    );
    await expectLater(save(), uncertain);
    api.timeout = false;
    api.malformed = true;
    await expectLater(save(), uncertain);
    await expectLater(
      api.repository.addContact(
        1,
        const WriteCustomerContactRequest(
          type: ContactType.phone,
          value: '+79162331046',
          label: null,
          isPrimary: true,
        ),
      ),
      uncertain,
    );
  });

  testWidgets(
    'name edit sends only changed fields, preserving historical and unavailable references',
    (tester) async {
      final api = EditApi();
      api.details['home_branch_id'] = 99;
      await openDialog(tester, editWindow(api));
      await saveName(tester, 'Анна Новая');
      expect(api.mutations.single.data, {
        'version': 3,
        'full_name': 'Анна Новая',
      });
      expect(find.byType(EditCustomerWindow), findsNothing);
    },
  );

  testWidgets(
    'unchanged form does not mutate; missing version never sends unchecked PATCH',
    (tester) async {
      final api = EditApi();
      await openDialog(tester, editWindow(api));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(api.mutations, isEmpty);
      api.details.remove('version');
      await openDialog(tester, editWindow(api));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Сохранить'),
            )
            .onPressed,
        isNull,
      );
      expect(api.mutations, isEmpty);
    },
  );

  testWidgets('birthday validation rejects invalid and cleared dates', (
    tester,
  ) async {
    final api = EditApi();
    await openDialog(tester, editWindow(api));
    await tester.enterText(
      find.byKey(const Key('edit-customer-birthday')),
      '31.02.2000',
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(api.mutations, isEmpty);
    expect(find.text('Укажите дату в формате дд.мм.гггг'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('edit-customer-birthday')), '');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Дату рождения нельзя очистить'), findsOneWidget);
  });

  testWidgets(
    'legacy null birthday can remain absent while changing the name',
    (tester) async {
      final api = EditApi();
      api.details['date_of_birth'] = null;
      await openDialog(tester, editWindow(api));
      await saveName(tester, 'Новое имя');
      expect(api.mutations.single.data, {
        'version': 3,
        'full_name': 'Новое имя',
      });
    },
  );

  testWidgets(
    'clearing optional selections sends explicit nulls, not missing keys',
    (tester) async {
      final api = EditApi();
      await openDialog(tester, editWindow(api));
      await tester.tap(find.byType(DropdownButtonFormField<CustomerGender>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Не указан').last);
      await tester.pumpAndSettle();
      for (var index = 0; index < 2; index++) {
        final field = find.byType(DropdownButtonFormField<int>).at(index);
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Не выбран').last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(api.mutations.single.data, {
        'version': 3,
        'gender': null,
        'home_branch_id': null,
        'responsible_employee_id': null,
      });
    },
  );

  testWidgets(
    'conflict preserves draft, requests reload, and prevents another save',
    (tester) async {
      final api = EditApi()..failureStatus = 409;
      var invalidated = false;
      await openDialog(
        tester,
        editWindow(api, refreshRequired: () => invalidated = true),
      );
      await saveName(tester, 'Черновик');
      expect(invalidated, isTrue);
      expect(find.text('Черновик'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Сохранить'),
            )
            .onPressed,
        isNull,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(api.mutations.length, 1);
    },
  );

  testWidgets(
    'validation error keeps save available, busy save cannot be closed or duplicated',
    (tester) async {
      final api = EditApi()
        ..failureStatus = 422
        ..errorCode = 'invalid_customer';
      await openDialog(tester, editWindow(api));
      await saveName(tester, 'Черновик');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Сохранить'),
            )
            .onPressed,
        isNotNull,
      );
      api.failureStatus = null;
      api.pending = Completer<void>();
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      expect(find.text('Сохраняем…'), findsOneWidget);
      // Dio queues interceptor callbacks; wait for dispatch, not save completion.
      for (var tick = 0; tick < 10 && api.mutations.length < 2; tick++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.byType(EditCustomerWindow), findsOneWidget);
      expect(api.mutations.length, 2);
      api.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(EditCustomerWindow), findsNothing);
      expect(api.mutations.length, 2);
    },
  );

  testWidgets(
    'new primary contact refreshes demoted old contact; archive needs explicit confirmation',
    (tester) async {
      final api = EditApi();
      var changes = 0;
      await openDialog(
        tester,
        CustomerContactsWindow(
          customer: CustomerDetails.fromJson(api.details),
          repository: api.repository,
          onChanged: () => changes++,
        ),
      );
      await tester.tap(find.text('Добавить контакт'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('contact-value')),
        '+79162331046',
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect((api.details['contacts'] as List).first['is_primary'], isFalse);
      expect(find.text('Телефон · Основной'), findsOneWidget);
      expect(
        api.requests
            .where((r) => r.method == 'GET' && r.path == '/customers/1')
            .length,
        1,
      );
      await tester.tap(find.byTooltip('Архивировать контакт').first);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(api.mutations.where((r) => r.method == 'DELETE'), isEmpty);
      await tester.tap(find.byTooltip('Архивировать контакт').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Архивировать'));
      await tester.pumpAndSettle();
      expect(changes, 2);
      expect(find.text('+79162331045'), findsNothing);
    },
  );

  testWidgets(
    'contact edit clears label, keeps type immutable and sends contact version',
    (tester) async {
      final api = EditApi();
      api.details['contacts'][0]['label'] = 'Рабочий';
      final contact = CustomerContact.fromJson(api.details['contacts'][0]);
      await openDialog(
        tester,
        CustomerContactEditor(
          contact: contact,
          onRefreshRequired: () {},
          onSave: (r) =>
              api.repository.updateContact(1, 1, r, version: contact.version!),
        ),
      );
      expect(
        tester
            .widget<DropdownButtonFormField<ContactType>>(
              find.byType(DropdownButtonFormField<ContactType>),
            )
            .onChanged,
        isNull,
      );
      await tester.enterText(find.byKey(const Key('contact-label')), '');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(api.mutations.single.data, {
        'value': '+79162331045',
        'label': null,
        'is_primary': true,
        'version': 2,
      });
    },
  );

  testWidgets('unknown contact type remains readable but cannot be rewritten', (
    tester,
  ) async {
    final api = EditApi();
    api.details['contacts'][0]['type'] = 'future_type';
    await openDialog(
      tester,
      CustomerContactEditor(
        contact: CustomerContact.fromJson(api.details['contacts'][0]),
        onRefreshRequired: () {},
        onSave: (r) => api.repository.addContact(1, r),
      ),
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Сохранить'))
          .onPressed,
      isNull,
    );
    expect(api.mutations, isEmpty);
  });

  for (final failRefresh in [false, true]) {
    testWidgets(
      'customer edit refreshes list/search and detail; reload failure=$failRefresh',
      (tester) async {
        final api = EditApi()..failRefresh = failRefresh;
        tester.view.physicalSize = const Size(1500, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: CustomersScreen(apiClient: api.client)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('customer-list-search')),
          'Петрова',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Анна Петрова').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('edit-customer-about')),
        );
        await tester.tap(find.byKey(const Key('edit-customer-about')));
        await tester.pumpAndSettle();
        await saveName(tester, 'Анна Новая Петрова');
        expect(api.mutations.length, 1);
        expect(find.byKey(const Key('customer-list-search')), findsOneWidget);
        expect(
          api.requests
              .lastWhere((r) => r.path == '/customers')
              .queryParameters['search'],
          'Петрова',
        );
        if (failRefresh) {
          expect(
            find.textContaining('Актуальные данные не получены'),
            findsOneWidget,
          );
          api.failRefresh = false;
          await tester.tap(find.byTooltip('Обновить карточку клиента'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Анна Новая Петрова'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
