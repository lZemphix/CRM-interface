import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/catalog/models/catalog_input.dart';
import 'package:crm_interface/modules/catalog/models/catalog_item.dart';
import 'package:crm_interface/modules/catalog/repos/catalog_repository.dart';
import 'package:crm_interface/modules/catalog/screens/catalog.dart';
import 'package:crm_interface/modules/catalog/widgets/catalog_item_form.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> itemJson({
  int id = 1,
  String name = 'Женская стрижка',
  String kind = 'service',
  bool active = true,
}) => {
  'id': id,
  'kind': kind,
  'category': 'Уход',
  'name': name,
  'description': null,
  'price': '2500.50',
  'duration_minutes': kind == 'service' ? 60 : null,
  'sku': kind == 'product' ? 'SH-250' : null,
  'is_active': active,
  'branches': [],
  'version': 3,
  'created_at': '2026-10-11T10:00:00Z',
  'updated_at': '2026-10-11T10:00:00Z',
  'branch': null,
};

Map<String, dynamic> pageJson(
  List<Map<String, dynamic>> items, {
  int? total,
  int offset = 0,
}) => {
  'items': items,
  'total': total ?? items.length,
  'offset': offset,
  'limit': 50,
  'counts': {'total': total ?? items.length, 'services': 1, 'products': 1},
};

CatalogItemInput input({CatalogKind kind = CatalogKind.service}) =>
    CatalogItemInput(
      kind: kind,
      category: 'Уход',
      name: 'Позиция',
      price: CatalogPrice.parse('1500,01'),
      description: null,
      durationMinutes: null,
      sku: null,
      isActive: true,
    );

class FixtureCatalogRepository extends CatalogRepository {
  FixtureCatalogRepository(super.apiClient);

  final requests =
      <({String search, CatalogKind? kind, String? category, int offset})>[];
  List<Map<String, dynamic>> items = [
    itemJson(),
    itemJson(id: 2, kind: 'product', name: 'Шампунь', active: false),
  ];
  Completer<CatalogPage>? delayed;
  bool fail = false;
  bool failCategories = false;
  int creates = 0;
  int updates = 0;
  int archives = 0;
  int? updatedVersion;
  CatalogItemInput? saved;
  int total = 2;

  @override
  Future<CatalogPage> getItems({
    String search = '',
    CatalogKind? kind,
    String? category,
    int offset = 0,
  }) async {
    requests.add((
      search: search,
      kind: kind,
      category: category,
      offset: offset,
    ));
    if (fail) throw const CatalogRequestException('Нет доступа к каталогу');
    if (search == 'old' && delayed != null) return delayed!.future;
    final shown = items
        .where(
          (item) =>
              (kind == null || item['kind'] == kind.apiValue) &&
              (category == null || item['category'] == category) &&
              (search.isEmpty || (item['name'] as String).contains(search)),
        )
        .toList();
    return CatalogPage.fromApi(
      pageJson(
        shown,
        total: search.isEmpty && kind == null && category == null
            ? total
            : shown.length,
        offset: offset,
      ),
    );
  }

  @override
  Future<List<String>> getCategories() async {
    if (failCategories) {
      throw const CatalogRequestException('Категории недоступны');
    }
    return ['Уход'];
  }

  @override
  Future<CatalogItemDetails> getItem(int id) async =>
      CatalogItemDetails.fromApi(items.firstWhere((item) => item['id'] == id));

  @override
  Future<CatalogItemDetails> createItem(CatalogItemInput value) async {
    creates++;
    saved = value;
    final item = itemJson(id: 3, name: value.name, kind: value.kind.apiValue);
    items.add(item);
    total++;
    return CatalogItemDetails.fromApi(item);
  }

  @override
  Future<CatalogItemDetails> updateItem(
    int id,
    CatalogItemInput value,
    int version,
  ) async {
    updates++;
    updatedVersion = version;
    saved = value;
    final item = items.firstWhere((entry) => entry['id'] == id);
    item['name'] = value.name;
    return CatalogItemDetails.fromApi({...item, 'version': version + 1});
  }

  @override
  Future<void> archiveItem(int id) async {
    archives++;
    items.removeWhere((item) => item['id'] == id);
    total--;
  }
}

void main() {
  late ApiClient api;
  late FixtureCatalogRepository repository;

  setUp(() {
    api = ApiClient(SessionStore());
    repository = FixtureCatalogRepository(api);
  });
  tearDown(() => api.dio.close(force: true));

  Future<void> showCatalog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CatalogScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> showForm(
    WidgetTester tester, {
    CatalogItemDetails? details,
    required Future<void> Function(CatalogItemInput) onSave,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => CatalogItemForm(
                  details: details,
                  categories: ['Уход'],
                  onSave: onSave,
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

  Future<void> enter(WidgetTester tester, String field, String value) async {
    final target = find.byKey(Key('catalog-form-$field'));
    await tester.ensureVisible(target);
    await tester.enterText(target, value);
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(WidgetTester tester) async {
    await enter(tester, 'category', 'Новая категория');
    await enter(tester, 'name', 'Новая услуга');
    await enter(tester, 'price', '1234,56');
  }

  test(
    'money parsing, formatting and JSON preserve kopecks without double',
    () {
      expect(CatalogPrice.parse('9999999999.99').toApi(), '9999999999.99');
      expect(CatalogPrice.parse('0').toApi(), '0.00');
      expect(CatalogPrice.parse(' 1500,01 ').kopecks, 150001);
      expect(CatalogPrice.parse('1500.01').formatted, contains(',01'));
      expect(CatalogPrice.parse('1500').formatted, isNot(contains(',00')));
      for (final invalid in [
        '',
        '-1',
        '1.001',
        '1e2',
        '10000000000',
        'NaN',
        'Infinity',
      ]) {
        expect(
          () => CatalogPrice.parse(invalid),
          throwsFormatException,
          reason: invalid,
        );
      }
    },
  );

  test('DTO reads both kinds, nullable fields, counts and immutable items', () {
    final page = CatalogPage.fromApi(
      pageJson([itemJson(), itemJson(id: 2, kind: 'product')]),
    );
    expect(page.items[0].subtitle, 'Услуга · 60 мин');
    expect(page.items[1].subtitle, 'Товар · SH-250');
    expect(page.items[1].description, isNull);
    expect(page.counts.total, 2);
    expect(() => page.items.clear(), throwsUnsupportedError);
    expect(CatalogPage.fromApi(pageJson([])).items, isEmpty);
    expect(() => CatalogKind.fromApi('other'), throwsFormatException);
  });

  test('create and PATCH distinguish immutable kind and nullable clearing', () {
    final create = input().toCreateApi();
    expect(create['kind'], 'service');
    expect(create['duration_minutes'], isNull);
    expect(create['price'], '1500.01');
    expect(create.containsKey('sku'), isFalse);
    final patch = input(kind: CatalogKind.product).toUpdateApi(7);
    expect(patch['version'], 7);
    expect(patch.containsKey('kind'), isFalse);
    expect(patch.containsKey('branches'), isFalse);
    expect(patch.containsKey('duration_minutes'), isFalse);
    expect(patch.containsKey('sku'), isTrue);
    expect(patch['sku'], isNull);
  });

  test(
    'repository uses confirmed catalog paths, filters and JSON command bodies',
    () async {
      final calls = <RequestOptions>[];
      api.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: options.method == 'POST'
                    ? 201
                    : options.method == 'DELETE'
                    ? 204
                    : 200,
                data: options.method == 'DELETE'
                    ? null
                    : options.path == '/catalog/categories'
                    ? ['Уход']
                    : options.path == '/catalog/items' &&
                          options.method == 'GET'
                    ? pageJson([itemJson()])
                    : itemJson(),
              ),
            );
          },
        ),
      );
      final repo = CatalogRepository(api);
      await repo.getItems(
        search: ' Стрижка ',
        kind: CatalogKind.service,
        category: 'Уход',
        offset: 50,
      );
      expect(calls.last.queryParameters, {
        'search': 'Стрижка',
        'kind': 'service',
        'category': 'Уход',
        'offset': 50,
        'limit': 50,
        'sort': 'name',
      });
      expect(await repo.getCategories(), ['Уход']);
      expect((await repo.getItem(1)).version, 3);
      await repo.createItem(input());
      expect(calls.last.data, input().toCreateApi());
      expect(calls.last.queryParameters, isEmpty);
      await repo.updateItem(1, input(), 3);
      expect(calls.last.method, 'PATCH');
      expect(calls.last.data, input().toUpdateApi(3));
      await repo.archiveItem(1);
      expect(calls.last.method, 'DELETE');
      expect(calls.last.path, '/catalog/items/1');
    },
  );

  test('repository translates permission, conflict, invalid and uncertain outcomes', () async {
    var status = 403;
    var malformed = false;
    api.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (malformed) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: options.method == 'POST' ? 201 : 200,
                data: {'items': 'bad'},
              ),
            );
          } else {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: status,
                  data: {
                    'detail': {
                      'code': 'version_conflict',
                      'message': 'Изменено',
                    },
                  },
                ),
              ),
            );
          }
        },
      ),
    );
    final repo = CatalogRepository(api);
    await expectLater(
      repo.getItems(),
      throwsA(
        isA<CatalogRequestException>().having(
          (e) => e.message,
          'message',
          contains('прав'),
        ),
      ),
    );
    status = 409;
    await expectLater(
      repo.updateItem(1, input(), 1),
      throwsA(
        isA<CatalogRequestException>().having(
          (e) => e.conflict,
          'conflict',
          true,
        ),
      ),
    );
    status = 503;
    await expectLater(
      repo.createItem(input()),
      throwsA(
        isA<CatalogRequestException>().having(
          (e) => e.uncertain,
          'uncertain',
          true,
        ),
      ),
    );
    malformed = true;
    await expectLater(
      repo.getItems(),
      throwsA(
        isA<CatalogRequestException>().having(
          (e) => e.uncertain,
          'uncertain',
          false,
        ),
      ),
    );
    await expectLater(
      repo.createItem(input()),
      throwsA(
        isA<CatalogRequestException>().having(
          (e) => e.uncertain,
          'uncertain',
          true,
        ),
      ),
    );
  });

  testWidgets(
    'list matches the template with server search, type/category filters and pagination',
    (tester) async {
      await showCatalog(tester);
      expect(find.text('Каталог'), findsOneWidget);
      expect(find.text('Женская стрижка'), findsOneWidget);
      expect(find.text('Шампунь'), findsOneWidget);
      expect(find.text('Скрыта'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('catalog-kind-product')));
      await tester.pumpAndSettle();
      expect(repository.requests.last.kind, CatalogKind.product);
      expect(find.text('Женская стрижка'), findsNothing);
      await tester.tap(find.byKey(const Key('catalog-category-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Уход').last);
      await tester.pumpAndSettle();
      expect(repository.requests.last.category, 'Уход');
      await tester.enterText(
        find.byKey(const Key('catalog-search')),
        'Шампунь',
      );
      await tester.pump(const Duration(milliseconds: 299));
      expect(repository.requests.last.search, '');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(repository.requests.last.search, 'Шампунь');
      expect(repository.requests.last.offset, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a late GET cannot overwrite newer search results', (
    tester,
  ) async {
    repository.delayed = Completer<CatalogPage>();
    await showCatalog(tester);
    await tester.enterText(find.byKey(const Key('catalog-search')), 'old');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byKey(const Key('catalog-search')), 'Шампунь');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    repository.delayed!.complete(
      CatalogPage.fromApi(pageJson([itemJson(name: 'Устаревшая позиция')])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Устаревшая позиция'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-row-2')),
        matching: find.text('Шампунь'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loading errors, retry, categories failure and empty results are explicit',
    (tester) async {
      repository.fail = true;
      repository.failCategories = true;
      await showCatalog(tester);
      expect(find.text('Нет доступа к каталогу'), findsOneWidget);
      expect(find.text('Категории недоступны'), findsOneWidget);
      repository.fail = false;
      repository.items = [];
      repository.total = 0;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Каталог пока пуст'), findsOneWidget);
      expect(find.byKey(const Key('catalog-add')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('catalog-search')), 'нет');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('create form validates and sends nullable service fields', (
    tester,
  ) async {
    CatalogItemInput? result;
    await showForm(tester, onSave: (value) async => result = value);
    await tester.tap(find.byKey(const Key('catalog-form-save')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Заполните поле'), findsWidgets);
    await fillForm(tester);
    await enter(tester, 'duration', '0');
    await tester.tap(find.byKey(const Key('catalog-form-save')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await enter(tester, 'duration', '');
    await tester.tap(find.byKey(const Key('catalog-form-save')));
    await tester.pumpAndSettle();
    expect(result!.name, 'Новая услуга');
    expect(result!.category, 'Новая категория');
    expect(result!.durationMinutes, isNull);
    expect(result!.price.toApi(), '1234.56');
    expect(find.byType(CatalogItemForm), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'product form sends SKU and preserves input while saving/conflicting',
    (tester) async {
      CatalogItemInput? result;
      final pending = Completer<void>();
      await showForm(
        tester,
        details: CatalogItemDetails.fromApi(itemJson(kind: 'product')),
        onSave: (value) async {
          result = value;
          await pending.future;
        },
      );
      expect(
        tester
            .widget<DropdownButtonFormField<CatalogKind>>(
              find.byKey(const Key('catalog-form-kind')),
            )
            .onChanged,
        isNull,
      );
      await enter(tester, 'sku', '  NEW-SKU  ');
      await tester.tap(find.byKey(const Key('catalog-form-save')));
      await tester.pump();
      expect(result!.sku, 'NEW-SKU');
      expect(result!.durationMinutes, isNull);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('catalog-form-save')))
            .onPressed,
        isNull,
      );
      pending.completeError(
        const CatalogRequestException('Конфликт версии', conflict: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Конфликт версии'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('catalog-form-sku')))
            .controller!
            .text,
        '  NEW-SKU  ',
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('catalog-form-save')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('create/edit/archive are confirmed by API and refresh the list', (
    tester,
  ) async {
    await showCatalog(tester);
    await tester.tap(find.byKey(const Key('catalog-add')));
    await tester.pumpAndSettle();
    await fillForm(tester);
    await tester.tap(find.byKey(const Key('catalog-form-save')));
    await tester.pumpAndSettle();
    expect(repository.creates, 1);
    expect(find.text('Новая услуга'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('catalog-edit-1')));
    await tester.pumpAndSettle();
    await enter(tester, 'name', 'Изменённая услуга');
    await tester.tap(find.byKey(const Key('catalog-form-save')));
    await tester.pumpAndSettle();
    expect(repository.updatedVersion, 3);
    expect(find.text('Изменённая услуга'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('catalog-archive-1')));
    await tester.pumpAndSettle();
    expect(repository.archives, 0);
    await tester.tap(find.byKey(const Key('catalog-confirm-archive')));
    await tester.pumpAndSettle();
    expect(repository.archives, 1);
    expect(find.text('Изменённая услуга'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('server pagination uses offset and search resets it', (
    tester,
  ) async {
    repository.total = 80;
    await showCatalog(tester);
    await tester.ensureVisible(find.byKey(const Key('catalog-next')));
    await tester.tap(find.byKey(const Key('catalog-next')));
    await tester.pumpAndSettle();
    expect(repository.requests.last.offset, 50);
    await tester.ensureVisible(find.byKey(const Key('catalog-search')));
    await tester.enterText(find.byKey(const Key('catalog-search')), 'Шампунь');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(repository.requests.last.offset, 0);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 720.0, 1280.0]) {
    testWidgets('catalog and form adapt to width $width without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showCatalog(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('catalog-add')));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogItemForm), findsOneWidget);
      await fillForm(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(repository.creates, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
