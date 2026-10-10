import 'package:crm_interface/bootstrap/modules.g.dart';
import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:crm_interface/core/modules/module_registry.dart';
import 'package:crm_interface/layout/app_shell.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/models/profile.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/modules/tasks/screens/tasks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestAuthRepository extends AuthRepository {
  TestAuthRepository(super.apiClient, super.sessionStore);

  @override
  Future<AuthProfile> getProfile() async => const AuthProfile(
    id: 1,
    login: 'fixture',
    fullName: 'Тестовый Сотрудник',
    roleName: 'Тестовая роль',
  );
}

class CounterSection extends StatefulWidget {
  const CounterSection({super.key, required this.label});

  final String label;

  @override
  State<CounterSection> createState() => _CounterSectionState();
}

class _CounterSectionState extends State<CounterSection> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => count++),
      child: Text('${widget.label}: $count'),
    );
  }
}

ModuleDefinition definition(
  String id, {
  int order = 100,
  WidgetBuilder? builder,
}) {
  return ModuleDefinition(
    id: id,
    title: id,
    description: 'Fixture section',
    icon: Icons.apps,
    order: order,
    screenBuilder: builder ?? (_) => CounterSection(label: id),
  );
}

void main() {
  late ApiClient api;
  late TestAuthRepository auth;

  setUp(() {
    api = ApiClient(SessionStore());
    auth = TestAuthRepository(api, api.sessionStore);
  });
  tearDown(() => api.dio.close(force: true));

  Future<void> showShell(WidgetTester tester, ModuleRegistry registry) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(modules: registry, authRepository: auth),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('generated registry preserves sections, order and module-owned dependencies', () {
    final registry = createModuleRegistry(api);
    expect(registry.modules.map((module) => module.id), [
      'customers',
      'tasks',
      'analytics',
      'catalog',
    ]);
    expect(registry['customers']!.title, 'Клиенты');
    expect(registry['missing'], isNull);
    final context = _UnusedContext();
    final first = registry['tasks']!.screenBuilder(context) as TasksScreen;
    final second = registry['tasks']!.screenBuilder(context) as TasksScreen;
    expect(identical(first.tasksRepository, second.tasksRepository), isTrue);
  });

  test('registry is immutable, ordered by priority then stable ID', () {
    final source = [
      definition('z'),
      definition('b', order: 1),
      definition('a', order: 1),
    ];
    final registry = ModuleRegistry(source);
    expect(registry.modules.map((module) => module.id), ['a', 'b', 'z']);
    source.clear();
    expect(registry.modules, hasLength(3));
    expect(() => registry.modules.add(definition('c')), throwsUnsupportedError);
    expect(registry.first!.id, 'a');
    expect(ModuleRegistry([]).first, isNull);
  });

  test('invalid or duplicate identifiers and empty titles fail explicitly', () {
    expect(
      () => ModuleRegistry([definition('a'), definition('a')]),
      throwsArgumentError,
    );
    expect(() => ModuleRegistry([definition('bad-id')]), throwsArgumentError);
    expect(
      () => ModuleRegistry([
        ModuleDefinition(
          id: 'a',
          title: ' ',
          description: '',
          icon: Icons.apps,
          screenBuilder: (_) => const SizedBox(),
        ),
      ]),
      throwsArgumentError,
    );
  });

  testWidgets(
    'arbitrary registered section appears and screens are created lazily',
    (tester) async {
      var builds = 0;
      final registry = ModuleRegistry([
        definition('first', order: 1),
        definition(
          'warehouse',
          builder: (_) {
            builds++;
            return const Text('Warehouse section');
          },
        ),
      ]);
      await showShell(tester, registry);
      expect(find.byTooltip('warehouse'), findsOneWidget);
      expect(builds, 0);
      await tester.tap(find.byKey(const ValueKey('sidebar-module-warehouse')));
      await tester.pumpAndSettle();
      expect(find.text('Warehouse section'), findsOneWidget);
      expect(builds, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('same widget types do not leak state between sections', (
    tester,
  ) async {
    final registry = ModuleRegistry([definition('a'), definition('b')]);
    await showShell(tester, registry);
    await tester.tap(find.text('a: 0'));
    await tester.pumpAndSettle();
    expect(find.text('a: 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sidebar-module-b')));
    await tester.pumpAndSettle();
    expect(find.text('b: 0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sidebar-module-a')));
    await tester.pumpAndSettle();
    expect(find.text('a: 0'), findsOneWidget);
  });

  testWidgets(
    'removed selection falls back and empty registry retains account controls',
    (tester) async {
      await showShell(
        tester,
        ModuleRegistry([definition('a'), definition('b')]),
      );
      await tester.tap(find.byKey(const ValueKey('sidebar-module-b')));
      await tester.pumpAndSettle();
      await showShell(tester, ModuleRegistry([definition('a')]));
      expect(find.text('a: 0'), findsOneWidget);
      expect(find.byKey(const ValueKey('sidebar-module-b')), findsNothing);
      await showShell(tester, ModuleRegistry([]));
      expect(find.text('Нет доступных разделов'), findsOneWidget);
      expect(find.byKey(const Key('sidebar-account')), findsOneWidget);
      expect(find.byKey(const Key('sidebar-settings')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

// Module screen factories in this test do not use the context.
class _UnusedContext extends Fake implements BuildContext {}
