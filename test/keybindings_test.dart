import 'dart:async';
import 'dart:convert';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/keyboard/command_scope.dart';
import 'package:crm_interface/core/keyboard/dialog_keyboard_scope.dart';
import 'package:crm_interface/core/keyboard/keybindings.dart';
import 'package:crm_interface/core/keyboard/keybindings_dialog.dart';
import 'package:crm_interface/core/keyboard/search_shortcut_scope.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/modules/auth/screens/auth_screen.dart';
import 'package:crm_interface/modules/tasks/widgets/create_column.dart';
import 'package:crm_interface/modules/customers/widgets/create_customer.dart';
import 'package:crm_interface/modules/customers/models/create_customer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryKeybindingsStore implements KeybindingsStore {
  String? value;
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    if (pending != null) await pending!.future;
    if (fail) throw PlatformException(code: 'storage_unavailable');
    value = text;
  }
}

class KeyboardAuthRepository extends AuthRepository {
  KeyboardAuthRepository(ApiClient client) : super(client, client.sessionStore);
  int requests = 0;
  Completer<bool>? pending;
  @override
  Future<bool> auth({required String login, required String password}) async {
    requests++;
    return pending == null ? false : pending!.future;
  }
}

Future<void> pressKey(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool meta = false,
  bool shift = false,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> openDialog(
  WidgetTester tester,
  Widget dialog, {
  KeybindingsController? controller,
}) async {
  Widget app = MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => dialog,
          ),
          child: const Text('Открыть'),
        ),
      ),
    ),
  );
  if (controller != null) {
    app = KeybindingsScope(controller: controller, child: app);
  }
  await tester.pumpWidget(app);
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
}

void main() {
  test('standard keys are platform-specific and Enter has two activators', () {
    final win = KeybindingsController(
      mac: false,
      store: MemoryKeybindingsStore(),
    );
    final mac = KeybindingsController(
      mac: true,
      store: MemoryKeybindingsStore(),
    );
    addTearDown(win.dispose);
    addTearDown(mac.dispose);
    expect(win.binding(AppCommand.submitForm).control, isTrue);
    expect(mac.binding(AppCommand.submitForm).meta, isTrue);
    expect(mac.binding(AppCommand.submitForm).control, isFalse);
    expect(win.binding(AppCommand.submitAuth).activators, hasLength(2));
    expect(
      const Keybinding(LogicalKeyboardKey.enter)
          .conflictsWith(const Keybinding(LogicalKeyboardKey.numpadEnter)),
      isTrue,
    );
  });

  test(
    'persisted overrides restore after restart without global state',
    () async {
      final store = MemoryKeybindingsStore();
      final first = KeybindingsController(store: store);
      await first.setBinding(
        AppCommand.closeDialog,
        const Keybinding(LogicalKeyboardKey.keyK, control: true),
      );
      final second = KeybindingsController(store: store);
      await second.load();
      expect(second.binding(AppCommand.closeDialog).label, 'Ctrl+K');
      expect(second.warning, isNull);
      final data = jsonDecode(store.value!) as Map;
      expect(data['version'], 1);
      expect((data['bindings'] as Map).keys, ['dialog.close']);
      first.dispose();
      second.dispose();
    },
  );

  test(
    'conflicts with defaults or Enter alias are rejected without writing',
    () async {
      final store = MemoryKeybindingsStore();
      final settings = KeybindingsController(mac: false, store: store);
      await expectLater(
        settings.setBinding(
          AppCommand.closeDialog,
          const Keybinding(LogicalKeyboardKey.enter, control: true),
        ),
        throwsA(isA<KeybindingException>()),
      );
      await expectLater(
        settings.setBinding(
          AppCommand.submitForm,
          const Keybinding(LogicalKeyboardKey.numpadEnter),
        ),
        throwsA(isA<KeybindingException>()),
      );
      expect(store.value, isNull);
      settings.dispose();
    },
  );

  test('same key is allowed in disjoint contexts', () async {
    final settings = KeybindingsController(store: MemoryKeybindingsStore());
    await settings.setBinding(
      AppCommand.closeDialog,
      const Keybinding(LogicalKeyboardKey.enter),
    );
    expect(
      settings.binding(AppCommand.closeDialog).key,
      LogicalKeyboardKey.enter,
    );
    expect(
      settings.binding(AppCommand.submitAuth).key,
      LogicalKeyboardKey.enter,
    );
    settings.dispose();
  });

  test('ordinary typing, editing and OS termination keys are protected', () {
    for (final binding in [
      const Keybinding(LogicalKeyboardKey.keyK),
      const Keybinding(LogicalKeyboardKey.keyK, shift: true),
      const Keybinding(LogicalKeyboardKey.tab),
      const Keybinding(LogicalKeyboardKey.keyC, control: true),
      const Keybinding(LogicalKeyboardKey.keyV, meta: true),
      const Keybinding(LogicalKeyboardKey.enter, shift: true),
      const Keybinding(LogicalKeyboardKey.altLeft),
      const Keybinding(LogicalKeyboardKey.f4, alt: true),
      const Keybinding(LogicalKeyboardKey.keyQ, meta: true),
      const Keybinding(LogicalKeyboardKey.keyK, control: true, alt: true),
    ]) {
      expect(binding.validate, throwsA(isA<KeybindingException>()));
    }
  });

  test('Unicode logical keys roundtrip through persisted JSON', () {
    const binding = Keybinding(LogicalKeyboardKey(0x0448), control: true);
    expect(
      Keybinding.fromJson(binding.toJson()).conflictsWith(binding),
      isTrue,
    );
  });

  for (final value in [
    'bad json',
    '{"version":2,"bindings":{}}',
    '{"version":1,"bindings":{"unknown":{}}}',
    '{"version":1,"bindings":{"dialog.close":{"key":-1}}}',
  ]) {
    test('invalid saved settings fall back safely: $value', () async {
      final store = MemoryKeybindingsStore()..value = value;
      final settings = KeybindingsController(store: store);
      await settings.load();
      expect(settings.warning, isNotNull);
      expect(
        settings.binding(AppCommand.closeDialog).key,
        LogicalKeyboardKey.escape,
      );
      settings.dispose();
    });
  }

  test('conflicting stored configuration is not applied', () async {
    final store = MemoryKeybindingsStore()
      ..value = jsonEncode({
        'version': 1,
        'bindings': {
          'form.submit': const Keybinding(LogicalKeyboardKey.enter).toJson(),
        },
      });
    final settings = KeybindingsController(store: store);
    await settings.load();
    expect(settings.warning, isNotNull);
    expect(
      settings.binding(AppCommand.closeDialog).key,
      LogicalKeyboardKey.escape,
    );
    settings.dispose();
  });

  test(
    'failed persistence preserves active binding and allows retry',
    () async {
      final store = MemoryKeybindingsStore()..fail = true;
      final settings = KeybindingsController(store: store);
      await expectLater(
        settings.setBinding(
          AppCommand.closeDialog,
          const Keybinding(LogicalKeyboardKey.f2),
        ),
        throwsA(isA<KeybindingException>()),
      );
      expect(
        settings.binding(AppCommand.closeDialog).key,
        LogicalKeyboardKey.escape,
      );
      expect(settings.saving, isFalse);
      store.fail = false;
      await settings.setBinding(
        AppCommand.closeDialog,
        const Keybinding(LogicalKeyboardKey.f2),
      );
      await settings.reset();
      expect(
        settings.binding(AppCommand.closeDialog).key,
        LogicalKeyboardKey.escape,
      );
      settings.dispose();
    },
  );

  test('overlapping saves do not overwrite each other', () async {
    final store = MemoryKeybindingsStore()..pending = Completer<void>();
    final settings = KeybindingsController(store: store);
    final save = settings.setBinding(
      AppCommand.closeDialog,
      const Keybinding(LogicalKeyboardKey.f2),
    );
    await expectLater(settings.reset(), throwsA(isA<KeybindingException>()));
    store.pending!.complete();
    await save;
    expect(settings.binding(AppCommand.closeDialog).key, LogicalKeyboardKey.f2);
    settings.dispose();
  });

  for (final enter in [
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  ]) {
    testWidgets(
      'Enter moves login to password then signs in: ${enter.keyLabel}',
      (tester) async {
        final client = ApiClient(SessionStore());
        final repository = KeyboardAuthRepository(client);
        var entered = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: AuthScreen(
              authRepository: repository,
              onAuthenticated: () => entered++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: fields.at(0),
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        await tester.enterText(fields.at(0), 'operator');
        await pressKey(tester, enter);
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: fields.at(1),
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        expect(repository.requests, 0);
        await tester.enterText(fields.at(1), 'test-password');
        await pressKey(tester, enter);
        expect(repository.requests, 1);
        expect(entered, 1);
        expect(find.text('Войти'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await client.close();
      },
    );
  }

  testWidgets('remapped login applies live and preserves entered text', (
    tester,
  ) async {
    final client = ApiClient(SessionStore());
    final repository = KeyboardAuthRepository(client);
    final settings = KeybindingsController(store: MemoryKeybindingsStore());
    await tester.pumpWidget(
      KeybindingsScope(
        controller: settings,
        child: MaterialApp(
          home: AuthScreen(authRepository: repository, onAuthenticated: () {}),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'operator');
    await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
    await settings.setBinding(
      AppCommand.submitAuth,
      const Keybinding(LogicalKeyboardKey.keyL, control: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('operator'), findsOneWidget);
    await pressKey(tester, LogicalKeyboardKey.enter);
    expect(repository.requests, 0);
    await tester.tap(find.byType(TextFormField).at(1));
    await pressKey(tester, LogicalKeyboardKey.keyL, control: true);
    expect(repository.requests, 1);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
    await client.close();
  });

  testWidgets('pending login ignores repeated Enter', (tester) async {
    final client = ApiClient(SessionStore());
    final repository = KeyboardAuthRepository(client)
      ..pending = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(authRepository: repository, onAuthenticated: () {}),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'operator');
    await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await pressKey(tester, LogicalKeyboardKey.enter);
    expect(repository.requests, 1);
    repository.pending!.complete(false);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await client.close();
  });

  testWidgets('Escape closes an empty modal without closing the page', (
    tester,
  ) async {
    await openDialog(
      tester,
      const DialogKeyboardScope(child: AlertDialog(title: Text('Диалог'))),
    );
    await pressKey(tester, LogicalKeyboardKey.escape);
    expect(find.text('Диалог'), findsNothing);
    expect(find.text('Открыть'), findsOneWidget);
  });

  testWidgets(
    'dirty modal confirms once, Escape preserves draft, submit is isolated',
    (tester) async {
      final text = TextEditingController();
      var submits = 0;
      await openDialog(
        tester,
        DialogKeyboardScope(
          hasChanges: () => text.text.isNotEmpty,
          onSubmit: () => submits++,
          child: AlertDialog(
            title: const Text('Редактор'),
            content: TextField(controller: text, autofocus: true),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Черновик');
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(find.text('Отменить изменения?'), findsOneWidget);
      await pressKey(tester, LogicalKeyboardKey.enter, control: true);
      expect(submits, 0);
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(find.text('Отменить изменения?'), findsNothing);
      expect(find.text('Черновик'), findsOneWidget);
      await pressKey(tester, LogicalKeyboardKey.escape);
      await tester.tap(find.text('Не сохранять'));
      await tester.pumpAndSettle();
      expect(find.text('Редактор'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      text.dispose();
    },
  );

  testWidgets('busy modal cannot be dismissed by Escape or system back', (
    tester,
  ) async {
    await openDialog(
      tester,
      const DialogKeyboardScope(
        busy: true,
        child: AlertDialog(title: Text('Сохранение')),
      ),
    );
    await pressKey(tester, LogicalKeyboardKey.escape);
    final context = tester.element(find.text('Сохранение'));
    await Navigator.of(context).maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Сохранение'), findsOneWidget);
  });

  testWidgets('only the uppermost modal closes', (tester) async {
    await openDialog(
      tester,
      DialogKeyboardScope(
        child: AlertDialog(
          title: const Text('Первый'),
          content: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const DialogKeyboardScope(
                  child: AlertDialog(title: Text('Второй')),
                ),
              ),
              child: const Text('Ещё'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ещё'));
    await tester.pumpAndSettle();
    await pressKey(tester, LogicalKeyboardKey.escape);
    expect(find.text('Второй'), findsNothing);
    expect(find.text('Первый'), findsOneWidget);
  });

  testWidgets('remapped Escape stops old native dismissal immediately', (
    tester,
  ) async {
    final settings = KeybindingsController(store: MemoryKeybindingsStore());
    await openDialog(
      tester,
      const DialogKeyboardScope(child: AlertDialog(title: Text('Диалог'))),
      controller: settings,
    );
    await settings.setBinding(
      AppCommand.closeDialog,
      const Keybinding(LogicalKeyboardKey.f2),
    );
    await tester.pumpAndSettle();
    await pressKey(tester, LogicalKeyboardKey.escape);
    expect(find.text('Диалог'), findsOneWidget);
    await pressKey(tester, LogicalKeyboardKey.f2);
    expect(find.text('Диалог'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
  });

  testWidgets(
    'Ctrl Enter validates, saves once, and busy blocks Escape in real column form',
    (tester) async {
      final pending = Completer<void>();
      var requests = 0;
      await openDialog(
        tester,
        CreateTaskColumnWindow(
          onCreate: (_) {
            requests++;
            return pending.future;
          },
        ),
      );
      await pressKey(tester, LogicalKeyboardKey.enter, control: true);
      expect(find.text('Введите название колонки'), findsOneWidget);
      expect(requests, 0);
      await tester.enterText(find.byType(TextFormField), 'Общая очередь');
      await pressKey(tester, LogicalKeyboardKey.enter, control: true);
      await pressKey(tester, LogicalKeyboardKey.enter, control: true);
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(requests, 1);
      expect(find.byType(CreateTaskColumnWindow), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CreateTaskColumnWindow), findsNothing);
    },
  );

  testWidgets('new customer draft is protected and Tab works in fields', (
    tester,
  ) async {
    await openDialog(
      tester,
      CreateCustomerWindow(
        loadOptions: () async => const CustomerCreationOptions(
          sources: [CustomerFormOption(id: 1, name: 'Сайт')],
          branches: [],
          employees: [],
        ),
        onCreate: (_) async => throw StateError('Not submitted'),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('customer-name')),
      'Тестовый клиент',
    );
    final name = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('customer-name')),
        matching: find.byType(EditableText),
      ),
    );
    expect(name.focusNode.hasFocus, isTrue);
    await pressKey(tester, LogicalKeyboardKey.tab);
    expect(name.focusNode.hasFocus, isFalse);
    await pressKey(tester, LogicalKeyboardKey.escape);
    expect(find.text('Отменить изменения?'), findsOneWidget);
    await pressKey(tester, LogicalKeyboardKey.escape);
    expect(find.text('Тестовый клиент'), findsOneWidget);
    await pressKey(tester, LogicalKeyboardKey.escape);
    await tester.tap(find.text('Не сохранять'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateCustomerWindow), findsNothing);
  });

  testWidgets('Enter in multiline text is not a form submit', (tester) async {
    final text = TextEditingController(text: 'Первая строка');
    var saves = 0;
    await openDialog(
      tester,
      DialogKeyboardScope(
        onSubmit: () => saves++,
        child: AlertDialog(
          content: TextField(controller: text, autofocus: true, maxLines: 4),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    text.selection = TextSelection.collapsed(offset: text.text.length);
    await pressKey(tester, LogicalKeyboardKey.enter);
    expect(saves, 0);
    // The native IME supplies text; synthetic KeyEvent does not do that.
    await tester.enterText(find.byType(TextField), 'Первая строка\n');
    expect(text.text, 'Первая строка\n');
    await pressKey(tester, LogicalKeyboardKey.enter, control: true);
    expect(saves, 1);
    await tester.pumpWidget(const SizedBox());
    text.dispose();
  });

  testWidgets('Mac uses Cmd Enter and does not require Ctrl', (tester) async {
    final settings = KeybindingsController(
      mac: true,
      store: MemoryKeybindingsStore(),
    );
    var saves = 0;
    await openDialog(
      tester,
      DialogKeyboardScope(
        onSubmit: () => saves++,
        child: const AlertDialog(title: Text('Форма')),
      ),
      controller: settings,
    );
    await pressKey(tester, LogicalKeyboardKey.enter, control: true);
    expect(saves, 0);
    await pressKey(tester, LogicalKeyboardKey.numpadEnter, meta: true);
    expect(saves, 1);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
  });

  testWidgets(
    'search shortcut focuses the field and does not cross a modal route',
    (tester) async {
      final node = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommandScope(
              commands: {AppCommand.focusSearch: node.requestFocus},
              autofocus: true,
              child: Column(
                children: [
                  TextField(focusNode: node),
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const DialogKeyboardScope(
                          child: AlertDialog(title: Text('Диалог')),
                        ),
                      ),
                      child: const Text('Модалка'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Модалка'));
      await tester.pumpAndSettle();
      await pressKey(tester, LogicalKeyboardKey.keyF, control: true);
      expect(node.hasFocus, isFalse);
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(find.text('Диалог'), findsNothing);
      await pressKey(tester, LogicalKeyboardKey.keyF, control: true);
      expect(node.hasFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
      node.dispose();
    },
  );

  testWidgets(
    'settings recorder applies live, old Escape stops working and reset restores it',
    (tester) async {
      final settings = KeybindingsController(store: MemoryKeybindingsStore());
      await openDialog(
        tester,
        KeybindingsDialog(controller: settings),
        controller: settings,
      );
      await tester.tap(find.byKey(const ValueKey('keybinding-dialog.close')));
      await tester.pumpAndSettle();
      await pressKey(tester, LogicalKeyboardKey.keyK, control: true);
      expect(find.text('Ctrl+K'), findsOneWidget);
      await tester.tap(find.byKey(const Key('apply-keybinding')));
      await tester.pumpAndSettle();
      expect(settings.binding(AppCommand.closeDialog).label, 'Ctrl+K');
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(find.text('Горячие клавиши'), findsOneWidget);
      await tester.tap(find.text('Восстановить все'));
      await tester.pumpAndSettle();
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(find.text('Горячие клавиши'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
    },
  );

  testWidgets('search works from sidebar and unregisters on section removal', (
    tester,
  ) async {
    final search = FocusNode();
    final sidebar = FocusNode();
    var showSearch = true;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchShortcutScope(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Row(
                  children: [
                    TextButton(
                      focusNode: sidebar,
                      onPressed: () {},
                      child: const Text('Панель'),
                    ),
                    if (showSearch)
                      Expanded(
                        child: RegisterSearchFocus(
                          node: search,
                          child: TextField(focusNode: search),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    sidebar.requestFocus();
    await tester.pumpAndSettle();
    await pressKey(tester, LogicalKeyboardKey.keyF, control: true);
    expect(search.hasFocus, isTrue);
    rebuild(() => showSearch = false);
    await tester.pumpAndSettle();
    sidebar.requestFocus();
    await tester.pumpAndSettle();
    await pressKey(tester, LogicalKeyboardKey.keyF, control: true);
    expect(sidebar.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    search.dispose();
    sidebar.dispose();
  });

  testWidgets('nested form action does not swallow an outer search action', (
    tester,
  ) async {
    var saves = 0;
    var searches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandScope(
            autofocus: true,
            commands: {AppCommand.focusSearch: () => searches++},
            child: CommandScope(
              commands: {AppCommand.submitForm: () => saves++},
              child: const TextField(autofocus: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await pressKey(tester, LogicalKeyboardKey.keyF, control: true);
    expect(searches, 1);
    expect(saves, 0);
    await pressKey(tester, LogicalKeyboardKey.enter, control: true);
    expect(saves, 1);
  });
}
