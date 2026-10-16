import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:crm_interface/core/modules/module_registry.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/core/keyboard/search_shortcut_scope.dart';
import 'package:crm_interface/layout/app_shell.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/models/profile.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class NavigationAuth extends AuthRepository {
  NavigationAuth(super.apiClient, super.sessionStore);

  int reads = 0;

  @override
  Future<AuthProfile> getProfile() async {
    reads++;
    return const AuthProfile(
      id: 1,
      login: 'fixture',
      fullName: 'Тестовый Сотрудник',
      roleName: 'Тестовая роль',
    );
  }
}

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key, required this.label});

  final String label;

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => count++),
      child: Text('${widget.label}: $count'),
    ),
  );
}

class SavedPage extends StatefulWidget {
  const SavedPage({super.key, required this.load});
  final Future<String> Function() load;
  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  final search = FocusNode();
  final text = TextEditingController();
  final scroll = ScrollController();
  late final Future<String> data;

  @override
  void initState() {
    super.initState();
    data = widget.load();
  }

  @override
  void dispose() {
    search.dispose();
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RegisterSearchFocus(
    node: search,
    child: Column(
      children: [
        TextField(controller: text, focusNode: search),
        FutureBuilder<String>(
          future: data,
          builder: (_, snapshot) => Text(snapshot.data ?? 'Загрузка страницы'),
        ),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            itemCount: 100,
            itemExtent: 40,
            itemBuilder: (_, index) => Text('Строка $index'),
          ),
        ),
      ],
    ),
  );
}

ModuleDefinition section(String id, {bool pinned = true, int order = 100}) =>
    ModuleDefinition(
      id: id,
      title: id,
      description: 'Fixture section',
      icon: Icons.apps,
      pinnedByDefault: pinned,
      order: order,
      screenBuilder: (_) => CounterScreen(label: id),
    );

Finder panel(String id) => find.byKey(ValueKey('sidebar-module-$id'));
Finder overflow(String id) => find.byKey(ValueKey('overflow-module-$id'));
final more = find.byKey(const Key('sidebar-more-modules'));

void main() {
  late ApiClient api;
  late NavigationAuth auth;
  late ModuleRegistry registry;

  setUp(() {
    api = ApiClient(SessionStore());
    auth = NavigationAuth(api, api.sessionStore);
    registry = ModuleRegistry([
      section('first', order: 1),
      section('catalog', pinned: false),
    ]);
  });
  tearDown(() => api.dio.close(force: true));

  Future<void> showShell(WidgetTester tester, {ModuleRegistry? modules}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(modules: modules ?? registry, authRepository: auth),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> rightClick(WidgetTester tester, Finder target) async {
    await tester.tap(target, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
  }

  Future<void> choosePlacement(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ValueKey('module-placement-$id')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'screens are created lazily and keep independent State on return',
    (tester) async {
      final modules = ModuleRegistry([
        section('first', order: 1),
        section('second'),
      ]);
      await showShell(tester, modules: modules);
      expect(find.byType(CounterScreen, skipOffstage: false), findsOneWidget);
      final first = tester.state(find.byType(CounterScreen));
      await tester.tap(find.text('first: 0'));
      await tester.tap(panel('second'));
      await tester.pumpAndSettle();
      expect(first.mounted, isTrue);
      expect(TickerMode.valuesOf(first.context).enabled, isFalse);
      expect(find.text('first: 1'), findsNothing);
      expect(find.byType(CounterScreen, skipOffstage: false), findsNWidgets(2));
      await tester.tap(find.text('second: 0'));
      await tester.tap(panel('first'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(CounterScreen)), same(first));
      expect(TickerMode.valuesOf(first.context).enabled, isTrue);
      expect(find.text('first: 1'), findsOneWidget);
      await tester.tap(panel('second'));
      await tester.pumpAndSettle();
      expect(find.text('second: 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(first.mounted, isFalse);
    },
  );

  testWidgets(
    'search shortcut follows the active cached module in either direction',
    (tester) async {
      final modules = ModuleRegistry([
        for (final id in ['first', 'second'])
          ModuleDefinition(
            id: id,
            title: id,
            description: 'Fixture',
            icon: Icons.apps,
            screenBuilder: (_) => SavedPage(load: () async => id),
          ),
      ]);
      await showShell(tester, modules: modules);
      final first = tester.state<_SavedPageState>(find.byType(SavedPage));
      await tester.tap(panel('second'));
      await tester.pumpAndSettle();
      final second = tester.state<_SavedPageState>(find.byType(SavedPage));
      for (final (id, current, hidden) in [
        ('second', second, first),
        ('first', first, second),
      ]) {
        await tester.tap(panel(id));
        await tester.pumpAndSettle();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(current.search.hasFocus, isTrue);
        expect(hidden.search.hasFocus, isFalse);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'return keeps data, draft and scroll; hidden search loses focus',
    (tester) async {
      var reads = 0;
      final modules = ModuleRegistry([
        ModuleDefinition(
          id: 'saved',
          title: 'Saved',
          description: 'Fixture',
          icon: Icons.apps,
          order: 1,
          screenBuilder: (_) => SavedPage(
            load: () async {
              reads++;
              return 'Загружено';
            },
          ),
        ),
        section('second'),
      ]);
      await showShell(tester, modules: modules);
      final page = tester.state<_SavedPageState>(find.byType(SavedPage));
      await tester.enterText(find.byType(TextField), 'Несохранённый поиск');
      page.scroll.jumpTo(600);
      await tester.pumpAndSettle();
      await tester.tap(panel('second'));
      await tester.pumpAndSettle();
      expect(page.search.hasFocus, isFalse);
      page.search.requestFocus();
      await tester.pump();
      expect(page.search.hasFocus, isFalse);
      // The sidebar shortcut must not focus a retained but invisible input.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(page.search.hasFocus, isFalse);
      await tester.tap(panel('saved'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(SavedPage)), same(page));
      expect(reads, 1);
      expect(page.scroll.offset, 600);
      expect(find.text('Несохранённый поиск'), findsOneWidget);
      expect(find.text('Загружено'), findsOneWidget);
      expect(find.text('Загрузка страницы'), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(page.search.hasFocus, isTrue);
      await showShell(tester, modules: ModuleRegistry(modules.modules));
      expect(page.mounted, isFalse);
      expect(reads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('additional sections open once and highlight the more button', (
    tester,
  ) async {
    await showShell(tester);
    expect(panel('first'), findsOneWidget);
    expect(panel('catalog'), findsNothing);
    expect(overflow('catalog'), findsNothing);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(overflow('catalog'), findsOneWidget);
    expect(overflow('first'), findsNothing);
    await tester.tap(overflow('catalog'));
    await tester.pumpAndSettle();
    expect(find.text('catalog: 0'), findsOneWidget);
    expect(overflow('catalog'), findsNothing);
    expect(
      tester.widget<IconButton>(more).style!.backgroundColor!.resolve({}),
      AppColors.activeElement,
    );
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(panel('first'));
    await tester.pumpAndSettle();
    expect(find.text('first: 0'), findsOneWidget);
    expect(auth.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pinning and unpinning preserve active screen State and ordering',
    (tester) async {
      await showShell(tester);
      await tester.tap(find.text('first: 0'));
      await tester.pumpAndSettle();
      await rightClick(tester, panel('first'));
      expect(find.text('Убрать из панели'), findsOneWidget);
      await choosePlacement(tester, 'first');
      expect(panel('first'), findsNothing);
      expect(find.text('first: 1'), findsOneWidget);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(overflow('first'), findsOneWidget);
      expect(overflow('catalog'), findsOneWidget);
      expect(
        tester.getTopLeft(overflow('first')).dy,
        lessThan(tester.getTopLeft(overflow('catalog')).dy),
      );
      await rightClick(tester, overflow('first'));
      expect(find.text('Закрепить в панели'), findsOneWidget);
      expect(overflow('catalog'), findsNothing);
      await choosePlacement(tester, 'first');
      expect(panel('first'), findsOneWidget);
      expect(find.text('first: 1'), findsOneWidget);
      expect(auth.reads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all pinned and empty registries have an explicit empty menu', (
    tester,
  ) async {
    await showShell(tester, modules: ModuleRegistry([section('only')]));
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Все разделы в панели'), findsOneWidget);
    expect(
      tester
          .widget<MenuItemButton>(
            find.widgetWithText(MenuItemButton, 'Все разделы в панели'),
          )
          .onPressed,
      isNull,
    );
    await tester.tapAt(const Offset(700, 400));
    await tester.pumpAndSettle();
    expect(find.text('Все разделы в панели'), findsNothing);
    await showShell(tester, modules: ModuleRegistry([]));
    expect(find.text('Нет доступных разделов'), findsOneWidget);
    expect(more, findsOneWidget);
    expect(find.byKey(const Key('sidebar-account')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling placement never changes navigation or selection', (
    tester,
  ) async {
    await showShell(tester);
    await rightClick(tester, panel('first'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel('first'), findsOneWidget);
    expect(find.text('first: 0'), findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await rightClick(tester, overflow('catalog'));
    await tester.tapAt(const Offset(700, 400));
    await tester.pumpAndSettle();
    expect(panel('catalog'), findsNothing);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(overflow('catalog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard can open, select and move sections without a mouse', (
    tester,
  ) async {
    await showShell(tester);
    tester.widget<IconButton>(more).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(overflow('catalog'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('catalog: 0'), findsOneWidget);
    tester.widget<IconButton>(more).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('Закрепить в панели'), findsOneWidget);
    await choosePlacement(tester, 'catalog');
    expect(panel('catalog'), findsOneWidget);
    expect(find.text('catalog: 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pointer dismissal tolerates gaps and cancels timers on dispose',
    (tester) async {
      await showShell(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 100));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(more));
      await tester.tap(more);
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(overflow('catalog')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(overflow('catalog'), findsOneWidget);
      await mouse.moveTo(const Offset(700, 400));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(overflow('catalog'), findsNothing);
      await mouse.moveTo(tester.getCenter(more));
      await tester.tap(more);
      await tester.pumpAndSettle();
      await mouse.moveTo(const Offset(700, 400));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new manifest defaults apply and removed overrides are discarded',
    (tester) async {
      await showShell(tester);
      await rightClick(tester, panel('first'));
      await choosePlacement(tester, 'first');
      await showShell(tester, modules: ModuleRegistry([section('new')]));
      expect(panel('new'), findsOneWidget);
      expect(find.text('new: 0'), findsOneWidget);
      await showShell(tester);
      expect(panel('first'), findsOneWidget);
      expect(panel('catalog'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a new AppShell resets session-only placement', (tester) async {
    await showShell(tester);
    await rightClick(tester, panel('first'));
    await choosePlacement(tester, 'first');
    expect(panel('first'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await showShell(tester);
    expect(panel('first'), findsOneWidget);
    expect(panel('catalog'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'many primary sections scroll while bottom actions stay visible',
    (tester) async {
      tester.view.physicalSize = const Size(800, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showShell(
        tester,
        modules: ModuleRegistry([
          for (var index = 0; index < 20; index++) section('module_$index'),
          section('extra', pinned: false),
        ]),
      );
      expect(
        tester.getBottomRight(find.byKey(const Key('sidebar-settings'))).dy,
        lessThanOrEqualTo(300),
      );
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(overflow('extra'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
