import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:crm_interface/modules/customers/widgets/customer_details/detail_panel.dart';
import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:crm_interface/modules/tasks/repos/request_error.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/create_task.dart';
import 'package:crm_interface/modules/tasks/widgets/customer_field.dart';
import 'package:crm_interface/modules/tasks/widgets/customer_tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/task_actions.dart';
import 'package:crm_interface/modules/tasks/widgets/task_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_interface/core/widgets/section_refresh_controller.dart';

import 'support/section_refresh.dart';

const customer = TaskCustomerOption(
  id: 7,
  fullName: 'Тестовый клиент',
  primaryContact: '+79162331045',
);
const column = TaskboardColumn(
  id: '1',
  name: 'Очередь',
  order: 0,
  countsAsDone: false,
  status: 'new',
  version: 1,
);

TaskboardTask linkedTask({int? customerId = 7}) => TaskboardTask(
  id: '12',
  columnId: '1',
  title: 'Связанная задача',
  description: '',
  priority: 'normal',
  customerId: customerId,
  customerName: customerId == null ? null : customer.fullName,
  status: 'new',
  subtasks: [],
  version: 4,
);

Future<void> openCreate(
  WidgetTester tester,
  Future<void> Function(CreateTaskRequest) onCreate, {
  TaskCustomerOption? initialCustomer,
  bool locked = false,
  Future<List<TaskCustomerOption>> Function(String)? search,
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
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => CreateTaskWindow(
                columns: const [column],
                employees: const [],
                onCreate: onCreate,
                initialCustomer: initialCustomer,
                lockCustomer: locked,
                searchCustomers: search ?? (_) async => [customer],
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
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Название *'),
    'Задача',
  );
}

Future<void> chooseCustomer(WidgetTester tester) async {
  final field = find.byKey(const Key('task-customer-search'));
  await tester.ensureVisible(field);
  await tester.enterText(field, 'Тест');
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, customer.fullName));
  await tester.pumpAndSettle();
}

class FakeCustomerTasksRepository extends TasksRepository {
  FakeCustomerTasksRepository() : super(ApiClient(SessionStore())) {
    addTearDown(refresh.dispose);
  }
  final refresh = SectionRefreshController();
  final ids = <int>[];
  final offsets = <int>[];
  List<TaskboardTask> tasks = [];
  bool fail = false;
  int? total;

  @override
  Future<TaskPage> getCustomerTasks(
    int customerId, {
    int limit = 20,
    int offset = 0,
    String sort = 'due_at',
  }) async {
    ids.add(customerId);
    offsets.add(offset);
    if (fail) throw const TaskRequestException('Нет доступа к задачам');
    return TaskPage(
      items: tasks,
      total: total ?? tasks.length,
      limit: limit,
      offset: offset,
    );
  }
}

void main() {
  testWidgets(
    'customer task pagination sends the selected offset and reload token resets the page',
    (tester) async {
      final repo = FakeCustomerTasksRepository()..total = 21;
      addTearDown(() => repo.apiClient.dio.close(force: true));
      Widget panel(int token) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [sectionRefreshButton(repo.refresh)]),
          body: CustomerTasksPanel(
            refreshController: repo.refresh,
            customerId: 7,
            repository: repo,
            reloadToken: token,
          ),
        ),
      );
      await tester.pumpWidget(panel(0));
      await tester.pumpAndSettle();
      expect(find.textContaining('Задачи клиента'), findsNothing);
      expect(find.text('Задачи'), findsNothing);
      expect(find.byTooltip('Обновить вкладку'), findsOneWidget);
      await tester.tap(find.byTooltip('Следующие задачи'));
      await tester.pumpAndSettle();
      expect(repo.offsets, [0, 20]);
      await tester.pumpWidget(panel(1));
      await tester.pumpAndSettle();
      expect(repo.offsets.last, 0);
    },
  );

  testWidgets(
    'task edit selects a different client and sends the replacement ID',
    (tester) async {
      EditTaskRequest? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => TaskActionWindow(
                    task: linkedTask(customerId: 4),
                    action: TaskCardAction.edit,
                    employees: const [],
                    searchCustomers: (_) async => [customer],
                    onEdit: (request) async => sent = request,
                    onAssign: (_) async {},
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
      await chooseCustomer(tester);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(sent!.toApi()['customer_id'], 7);
    },
  );

  testWidgets(
    'customer detail creates a linked task and its task tab reads the same server record',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = ApiClient(SessionStore());
      addTearDown(() => client.dio.close(force: true));
      Map<String, dynamic>? submitted;
      final taskJson = <String, dynamic>{
        'id': 12,
        'column_id': 1,
        'title': 'Созданная задача',
        'description': '',
        'priority': 'normal',
        'status': 'new',
        'due_at': null,
        'due_date': null,
        'customer': {'id': 7, 'full_name': customer.fullName},
        'subtasks': [],
        'version': 1,
      };
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (request, handler) {
            dynamic data;
            switch (request.path) {
              case '/customers/7':
                data = {
                  'id': 7,
                  'full_name': customer.fullName,
                  'gender': null,
                  'date_of_birth': '1992-03-15',
                  'status': 'active',
                  'acquisition_source_id': 1,
                  'acquisition_source_code': 'website',
                  'acquisition_source_name': 'Сайт',
                  'registration_method': 'employee',
                  'created_at': '2026-10-07T12:00:00Z',
                  'updated_at': '2026-10-07T12:00:00Z',
                  'contacts': [],
                  'notes': [],
                };
              case '/task-columns':
                data = [
                  {
                    'id': 1,
                    'name': 'Очередь',
                    'status': 'new',
                    'order': 0,
                    'counts_as_done': false,
                    'version': 1,
                  },
                ];
              case '/employees':
                data = <dynamic>[];
              case '/tasks':
                if (request.method == 'POST') {
                  submitted = Map<String, dynamic>.from(request.data as Map);
                  data = taskJson;
                } else {
                  expect(request.queryParameters['customer_id'], 7);
                  data = {
                    'items': submitted == null ? [] : [taskJson],
                    'total': submitted == null ? 0 : 1,
                    'limit': 20,
                    'offset': 0,
                  };
                }
              case '/customers/7/activity':
                data = {'items': [], 'total': 0, 'limit': 20, 'offset': 0};
              case '/branches':
                data = <dynamic>[];
              default:
                fail('Unexpected request: ${request.path}');
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
            body: DetailPanel(
              apiClient: client,
              customer: const Customer(
                id: 7,
                fullName: 'Тестовый клиент',
                status: 'active',
                acquisitionSourceName: 'Сайт',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('У клиента нет незавершённых задач'), findsOneWidget);
      await tester.tap(find.text('+ Задача'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateTaskWindow), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Название *'),
        'Созданная задача',
      );
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(submitted!['customer_id'], 7);
      expect(find.byType(CreateTaskWindow), findsNothing);
      expect(find.text('Созданная задача'), findsOneWidget);
      await tester.tap(find.text('Задачи'));
      await tester.pumpAndSettle();
      expect(find.text('Созданная задача'), findsOneWidget);
      expect(tester.widget<TaskCard>(find.byType(TaskCard)).task.id, '12');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'create links the selected API customer instead of sending entered text',
    (tester) async {
      CreateTaskRequest? sent;
      await openCreate(tester, (request) async => sent = request);
      await chooseCustomer(tester);
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(sent!.toApi()['customer_id'], 7);
    },
  );

  testWidgets(
    'typed but unselected customer blocks submit; clear creates an internal task',
    (tester) async {
      CreateTaskRequest? sent;
      await openCreate(
        tester,
        (request) async => sent = request,
        search: (_) async => [],
      );
      await tester.enterText(
        find.byKey(const Key('task-customer-search')),
        'Не выбран',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(sent, isNull);
      expect(
        find.text('Выберите клиента из подсказок или очистите поле'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Убрать привязку к клиенту'));
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(sent!.customerId, isNull);
    },
  );

  testWidgets('creation from customer locks the preselected relation', (
    tester,
  ) async {
    CreateTaskRequest? sent;
    await openCreate(
      tester,
      (request) async => sent = request,
      initialCustomer: customer,
      locked: true,
    );
    expect(find.byTooltip('Убрать привязку к клиенту'), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.widgetWithText(TextFormField, 'Клиент'),
              matching: find.byType(TextField),
            ),
          )
          .readOnly,
      isTrue,
    );
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(sent!.customerId, 7);
  });

  testWidgets('search debounce avoids obsolete results and displays failures', (
    tester,
  ) async {
    final queries = <String>[];
    final old = Completer<List<TaskCustomerOption>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCustomerField(
            onSelected: (_) {},
            searchCustomers: (query) {
              queries.add(query);
              if (query == 'старый') return old.future;
              return Future.error(
                const TaskRequestException('Поиск недоступен'),
              );
            },
          ),
        ),
      ),
    );
    final field = find.byKey(const Key('task-customer-search'));
    await tester.enterText(field, 'ста');
    await tester.enterText(field, 'старый');
    await tester.pump(const Duration(milliseconds: 350));
    expect(queries, ['старый']);
    await tester.enterText(field, 'новый');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Поиск недоступен'), findsOneWidget);
    old.complete([customer]);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets(
    'edit can unlink an existing task without deleting other fields',
    (tester) async {
      EditTaskRequest? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => TaskActionWindow(
                    task: linkedTask(),
                    action: TaskCardAction.edit,
                    employees: const [],
                    searchCustomers: (_) async => [customer],
                    onEdit: (request) async => sent = request,
                    onAssign: (_) async {},
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
      await tester.tap(find.byTooltip('Убрать привязку к клиенту'));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(sent!.toApi()['customer_id'], isNull);
      expect(sent!.toApi().containsKey('customer_id'), isTrue);
      expect(sent!.version, 4);
      expect(sent!.title, 'Связанная задача');
    },
  );

  testWidgets(
    'customer task tab has empty/error/retry/data states and reloads on new client',
    (tester) async {
      final repo = FakeCustomerTasksRepository();
      addTearDown(() => repo.apiClient.dio.close(force: true));
      Widget panel(int id, int token) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [sectionRefreshButton(repo.refresh)]),
          body: CustomerTasksPanel(
            refreshController: repo.refresh,
            customerId: id,
            repository: repo,
            reloadToken: token,
          ),
        ),
      );
      await tester.pumpWidget(panel(7, 0));
      await tester.pumpAndSettle();
      expect(find.text('У клиента пока нет задач'), findsOneWidget);
      repo.fail = true;
      await tester.tap(find.byTooltip('Обновить вкладку'));
      await tester.pumpAndSettle();
      expect(find.text('Нет доступа к задачам'), findsOneWidget);
      repo.fail = false;
      repo.tasks = [linkedTask()];
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskCard), findsOneWidget);
      expect(tester.widget<TaskCard>(find.byType(TaskCard)).compact, isTrue);
      expect(find.text('Связанная задача'), findsOneWidget);
      await tester.pumpWidget(panel(9, 1));
      await tester.pumpAndSettle();
      expect(repo.ids.last, 9);
      expect(tester.takeException(), isNull);
    },
  );

  test('API search and list use server filters; PATCH distinguishes keep/link/unlink', () async {
    final client = ApiClient(SessionStore());
    addTearDown(() => client.dio.close(force: true));
    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.path == '/customers') {
            expect(request.queryParameters, {
              'search': 'Тест',
              'status': 'active',
              'limit': 20,
              'offset': 0,
            });
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'items': [
                    {
                      'id': 7,
                      'full_name': customer.fullName,
                      'primary_contact': null,
                    },
                  ],
                },
              ),
            );
          } else {
            expect(request.path, '/tasks');
            expect(request.queryParameters, {
              'customer_id': 7,
              'limit': 20,
              'offset': 20,
              'sort': 'due_at',
            });
            handler.resolve(
              Response(
                requestOptions: request,
                data: {'items': [], 'total': 0, 'limit': 20, 'offset': 20},
              ),
            );
          }
        },
      ),
    );
    final repo = TasksRepository(client);
    expect((await repo.searchCustomers('  Тест  ')).single.id, 7);
    expect((await repo.getCustomerTasks(7, offset: 20)).items, isEmpty);
    EditTaskRequest edit({bool update = false, int? id}) => EditTaskRequest(
      title: 'Задача',
      description: '',
      priority: Priority.normal,
      version: 4,
      updateCustomer: update,
      customerId: id,
    );
    expect(edit().toApi().containsKey('customer_id'), isFalse);
    expect(edit(update: true, id: 7).toApi()['customer_id'], 7);
    expect(edit(update: true).toApi().containsKey('customer_id'), isTrue);
    expect(edit(update: true).toApi()['customer_id'], isNull);
  });
}
