import 'dart:async';

import 'package:appflowy_board/appflowy_board.dart';
import 'package:crm_interface/app.dart';
import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/keyboard/command_scope.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:crm_interface/core/modules/module_registry.dart';
import 'package:crm_interface/core/theme/app_palette.dart';
import 'package:crm_interface/core/theme/appearance_settings.dart';
import 'package:crm_interface/core/theme/theme_settings.dart';
import 'package:crm_interface/layout/app_shell.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/models/profile.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/modules/auth/screens/auth_screen.dart';
import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/screens/tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/column_decoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class MemoryThemeSettings implements ThemeSettingsStore {
  MemoryThemeSettings([this.value]);
  String? value;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  Completer<String?>? pendingRead;
  Completer<void>? pendingWrite;
  @override
  Future<String?> read() async {
    if (failRead) throw const ThemeSettingsException();
    return pendingRead == null ? value : pendingRead!.future;
  }

  @override
  Future<void> write(String theme) async {
    writes++;
    if (pendingWrite != null) await pendingWrite!.future;
    if (failWrite) throw const ThemeSettingsException();
    value = theme;
  }
}

class ThemeAuth extends AuthRepository {
  ThemeAuth(ApiClient api) : super(api, api.sessionStore);
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

class ThemeBoard extends TasksRepository {
  ThemeBoard(super.apiClient);
  int reads = 0;
  @override
  Future<Taskboard> getTaskBoard() async {
    reads++;
    return Taskboard(
      columns: const [
        TaskboardColumn(
          id: '1',
          name: 'Очередь',
          order: 0,
          countsAsDone: false,
          status: null,
          version: 1,
        ),
      ],
      tasks: [
        for (var i = 100; i < 120; i++)
          TaskboardTask(
            id: '$i',
            columnId: '1',
            title: 'Задача $i',
            description: 'Полное описание',
            priority: 'normal',
            responsibleEmployeeId: i == 100 ? 1 : null,
            version: 1,
            subtasks: const [
              TaskboardTaskSubtask(
                id: 1,
                title: 'Проверить',
                done: false,
                order: 0,
              ),
            ],
          ),
      ],
    );
  }
}

class ThemeDraft extends StatefulWidget {
  const ThemeDraft({super.key, this.onFirstPalette});
  final ValueChanged<Color>? onFirstPalette;
  @override
  State<ThemeDraft> createState() => ThemeDraftState();
}

class ThemeDraftState extends State<ThemeDraft> {
  final text = TextEditingController();
  int builds = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (builds++ == 0) widget.onFirstPalette?.call(context.colors.background);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextField(key: const Key('theme-draft'), controller: text),
        TextButton(
          onPressed: () => showAppearanceSettings(context),
          child: const Text('Оформление'),
        ),
      ],
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('login keeps stored theme without settings buttons', (
    tester,
  ) async {
    final c = ThemeController(store: MemoryThemeSettings('dark'));
    final api = ApiClient(SessionStore());
    addTearDown(c.dispose);
    addTearDown(() => api.dio.close(force: true));
    await tester.pumpWidget(
      KeybindingsHost(
        child: CrmAppFrame(
          themeController: c,
          home: AuthScreen(
            authRepository: ThemeAuth(api),
            onAuthenticated: () {},
            onConfigureServer: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Внешний вид'), findsNothing);
    expect(find.text('Горячие клавиши'), findsNothing);
    expect(find.byKey(const Key('login-appearance')), findsNothing);
    expect(find.byKey(const Key('login-keybindings')), findsNothing);
    expect(find.byKey(const Key('configure-server')), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(AuthScreen))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  test('saved theme persists through the real preferences adapter', () async {
    final first = ThemeController();
    await first.load();
    expect(first.mode, ThemeMode.light);
    await first.setMode(ThemeMode.dark);
    first.dispose();
    final second = ThemeController();
    await second.load();
    expect(second.mode, ThemeMode.dark);
    expect(second.warning, isNull);
    second.dispose();
  });

  test(
    'invalid or unavailable preference falls back safely to light',
    () async {
      for (final store in [
        MemoryThemeSettings('invalid'),
        MemoryThemeSettings()..failRead = true,
      ]) {
        final c = ThemeController(store: store);
        await c.load();
        expect(c.loaded, isTrue);
        expect(c.mode, ThemeMode.light);
        expect(c.warning, isNotNull);
        c.dispose();
      }
    },
  );

  test('live change survives failed persistence and can retry', () async {
    final store = MemoryThemeSettings()..failWrite = true;
    final c = ThemeController(store: store);
    await c.load();
    await c.setMode(ThemeMode.dark);
    expect(c.mode, ThemeMode.dark);
    expect(c.saving, isFalse);
    expect(c.warning, contains('сохранить'));
    store.failWrite = false;
    await c.setMode(ThemeMode.dark);
    expect(store.value, 'dark');
    expect(c.warning, isNull);
    await c.setMode(ThemeMode.system);
    expect(c.mode, ThemeMode.dark);
    c.dispose();
  });

  test(
    'saving is single-flight and late completions tolerate dispose',
    () async {
      final store = MemoryThemeSettings()..pendingWrite = Completer<void>();
      final c = ThemeController(store: store);
      await c.load();
      final save = c.setMode(ThemeMode.dark);
      await c.setMode(ThemeMode.light);
      expect(c.mode, ThemeMode.dark);
      expect(store.writes, 1);
      c.dispose();
      store.pendingWrite!.complete();
      await save;
      final reader = MemoryThemeSettings()..pendingRead = Completer<String?>();
      final d = ThemeController(store: reader);
      final load = d.load();
      d.dispose();
      reader.pendingRead!.complete('dark');
      await load;
    },
  );

  test(
    'palette matches prototype and interpolates without changing endpoints',
    () {
      expect(AppPalette.dark.background, const Color(0xFF141C29));
      expect(AppPalette.dark.surface, const Color(0xFF1C2535));
      expect(AppPalette.dark.taskColumnBackground, const Color(0xFF192231));
      expect(AppPalette.dark.ownTaskBackground, const Color(0xFF21364D));
      expect(AppPalette.dark.accent, const Color(0xFFA4A4FF));
      expect(
        AppPalette.light.lerp(AppPalette.dark, .5).background,
        Color.lerp(AppPalette.light.background, AppPalette.dark.background, .5),
      );
      expect(
        AppPalette.light.lerp(AppPalette.dark, 0).surface,
        AppPalette.light.surface,
      );
      expect(
        AppPalette.light.lerp(AppPalette.dark, 1).surface,
        AppPalette.dark.surface,
      );
    },
  );

  testWidgets(
    'first content frame uses stored dark; live changes preserve drafts',
    (tester) async {
      final store = MemoryThemeSettings()..pendingRead = Completer<String?>();
      final c = ThemeController(store: store);
      addTearDown(c.dispose);
      final firstColors = <Color>[];
      await tester.pumpWidget(
        CrmAppFrame(
          themeController: c,
          home: ThemeDraft(onFirstPalette: firstColors.add),
        ),
      );
      expect(find.byType(ThemeDraft), findsNothing);
      store.pendingRead!.complete('dark');
      await tester.pumpAndSettle();
      expect(firstColors, [AppPalette.dark.background]);
      final state = tester.state(find.byType(ThemeDraft));
      await tester.enterText(
        find.byKey(const Key('theme-draft')),
        'Не терять черновик',
      );
      await tester.tap(find.text('Оформление'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-option-light')));
      await tester.pumpAndSettle();
      expect(c.mode, ThemeMode.light);
      expect(tester.state(find.byType(ThemeDraft)), same(state));
      expect(find.text('Не терять черновик'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceSettings), findsNothing);
      expect(store.value, 'light');
    },
  );

  testWidgets(
    'theme updates cached board cards and painter without scroll reset or GET',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = ThemeController(store: MemoryThemeSettings());
      addTearDown(c.dispose);
      final api = ApiClient(SessionStore());
      addTearDown(() => api.dio.close(force: true));
      final auth = ThemeAuth(api), repo = ThemeBoard(api);
      final registry = ModuleRegistry([
        ModuleDefinition(
          id: 'tasks',
          title: 'Задачи',
          description: 'Fixture',
          icon: Icons.task_alt,
          screenBuilder: (_) => TasksScreen(tasksRepository: repo),
        ),
      ]);
      await tester.pumpWidget(
        CrmAppFrame(
          themeController: c,
          home: AppShell(modules: registry, authRepository: auth),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(TasksScreen));
      final boardView = tester.widget<AppFlowyBoard>(
        find.byType(AppFlowyBoard),
      );
      final firstCard = find.byKey(const ValueKey('100'));
      await tester.tap(
        find.descendant(of: firstCard, matching: find.text('Подзадачи · 0/1')),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .stateList<ScrollableState>(
            find.ancestor(of: firstCard, matching: find.byType(Scrollable)),
          )
          .singleWhere(
            (s) => axisDirectionToAxis(s.widget.axisDirection) == Axis.vertical,
          );
      scroll.position.jumpTo(450);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sidebar-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-option-dark')));
      await tester.pumpAndSettle();
      final card = tester.widget<AppFlowyGroupCard>(
        find.descendant(
          of: firstCard,
          matching: find.byType(AppFlowyGroupCard),
        ),
      );
      expect(card.decoration.color, AppPalette.dark.ownTaskBackground);
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<TaskColumnFrames>()
          .single;
      expect(painter.fillColor, AppPalette.dark.taskColumnBackground);
      expect(painter.borderColor, AppPalette.dark.notActiveBorder);
      expect(
        tester.widget<AppFlowyBoard>(find.byType(AppFlowyBoard)),
        same(boardView),
      );
      expect(tester.state(find.byType(TasksScreen)), same(state));
      expect(scroll.position.pixels, 450);
      expect(repo.reads, 1);
      expect(auth.reads, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      scroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        find
            .descendant(of: firstCard, matching: find.text('Проверить'))
            .hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings work at narrow width and preserve a failed-save selection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = ThemeController(store: MemoryThemeSettings()..failWrite = true);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        CrmAppFrame(themeController: c, home: const ThemeDraft()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Оформление'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-option-dark')));
      await tester.pumpAndSettle();
      expect(c.mode, ThemeMode.dark);
      expect(find.textContaining('сохранить выбор'), findsOneWidget);
      expect(tester.getSize(find.byType(Dialog)).width, lessThanOrEqualTo(390));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('close-appearance-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceSettings), findsNothing);
    },
  );
}
