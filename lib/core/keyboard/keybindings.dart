import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppCommand {
  closeDialog('dialog.close', 'Закрыть диалог'),
  submitForm('form.submit', 'Сохранить форму'),
  submitAuth('auth.submit', 'Далее / войти'),
  focusSearch('search.focus', 'Перейти к поиску');

  const AppCommand(this.id, this.label);
  final String id;
  final String label;

  // Save coexists with auth, inline-note search, and modal close. The other
  // commands are active in different contexts/routes.
  bool overlaps(AppCommand other) =>
      this == other ||
      this == AppCommand.submitForm ||
      other == AppCommand.submitForm;
}

class KeybindingException implements Exception {
  const KeybindingException(this.message);
  final String message;
}

@immutable
class Keybinding {
  const Keybinding(
    this.key, {
    this.control = false,
    this.shift = false,
    this.alt = false,
    this.meta = false,
  });
  final LogicalKeyboardKey key;
  final bool control;
  final bool shift;
  final bool alt;
  final bool meta;

  factory Keybinding.fromEvent(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    return Keybinding(
      event.logicalKey,
      control: keyboard.isControlPressed,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      meta: keyboard.isMetaPressed,
    );
  }

  factory Keybinding.fromJson(Object? value) {
    if (value is! Map ||
        value['key'] is! int ||
        ['control', 'shift', 'alt', 'meta'].any((key) => value[key] is! bool)) {
      throw const FormatException('Invalid keybinding');
    }
    final id = value['key'] as int;
    final key =
        LogicalKeyboardKey.findKeyByKeyId(id) ??
        (id >= 0x20 && id <= 0x10ffff ? LogicalKeyboardKey(id) : null);
    if (key == null) throw const FormatException('Unknown key');
    return Keybinding(
      key,
      control: value['control'] as bool,
      shift: value['shift'] as bool,
      alt: value['alt'] as bool,
      meta: value['meta'] as bool,
    );
  }

  Map<String, Object> toJson() => {
    'key': key.keyId,
    'control': control,
    'shift': shift,
    'alt': alt,
    'meta': meta,
  };

  static bool isModifier(LogicalKeyboardKey key) => const [
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.numLock,
  ].contains(key);

  LogicalKeyboardKey get _normalized =>
      key == LogicalKeyboardKey.numpadEnter ? LogicalKeyboardKey.enter : key;

  Iterable<ShortcutActivator> get activators sync* {
    yield SingleActivator(
      _normalized,
      control: control,
      shift: shift,
      alt: alt,
      meta: meta,
      includeRepeats: false,
    );
    if (_normalized == LogicalKeyboardKey.enter) {
      yield SingleActivator(
        LogicalKeyboardKey.numpadEnter,
        control: control,
        shift: shift,
        alt: alt,
        meta: meta,
        includeRepeats: false,
      );
    }
  }

  String get label => [
    if (control) 'Ctrl',
    if (alt) 'Alt',
    if (shift) 'Shift',
    if (meta) 'Cmd',
    _normalized.keyLabel,
  ].join('+');

  bool conflictsWith(Keybinding other) =>
      _normalized == other._normalized &&
      control == other.control &&
      shift == other.shift &&
      alt == other.alt &&
      meta == other.meta;

  void validate() {
    const editingKeys = [
      LogicalKeyboardKey.tab,
      LogicalKeyboardKey.backspace,
      LogicalKeyboardKey.delete,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
      LogicalKeyboardKey.pageUp,
      LogicalKeyboardKey.pageDown,
    ];
    const editingLetters = [
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.keyV,
      LogicalKeyboardKey.keyX,
      LogicalKeyboardKey.keyY,
      LogicalKeyboardKey.keyZ,
    ];
    const functionKeys = [
      LogicalKeyboardKey.f1,
      LogicalKeyboardKey.f2,
      LogicalKeyboardKey.f3,
      LogicalKeyboardKey.f4,
      LogicalKeyboardKey.f5,
      LogicalKeyboardKey.f6,
      LogicalKeyboardKey.f7,
      LogicalKeyboardKey.f8,
      LogicalKeyboardKey.f9,
      LogicalKeyboardKey.f10,
      LogicalKeyboardKey.f11,
      LogicalKeyboardKey.f12,
    ];
    if (isModifier(key) ||
        editingKeys.contains(key) ||
        ((control || meta) && editingLetters.contains(key)) ||
        (control && alt) || // AltGr is text input, not an application command.
        (alt && key == LogicalKeyboardKey.f4) ||
        (meta &&
            const [
              LogicalKeyboardKey.keyQ,
              LogicalKeyboardKey.keyW,
              LogicalKeyboardKey.keyM,
              LogicalKeyboardKey.space,
            ].contains(key)) ||
        (!control &&
            !alt &&
            !meta &&
            !functionKeys.contains(key) &&
            _normalized != LogicalKeyboardKey.escape &&
            !(_normalized == LogicalKeyboardKey.enter && !shift))) {
      throw const KeybindingException(
        'Выберите сочетание с Ctrl, Alt или Cmd либо Enter, Esc, F1–F12. '
        'Клавиши ввода, редактирования текста и закрытия приложения защищены.',
      );
    }
  }

  static Keybinding standard(AppCommand command, {required bool mac}) =>
      switch (command) {
        AppCommand.closeDialog => const Keybinding(LogicalKeyboardKey.escape),
        AppCommand.submitAuth => const Keybinding(LogicalKeyboardKey.enter),
        AppCommand.submitForm => Keybinding(
          LogicalKeyboardKey.enter,
          control: !mac,
          meta: mac,
        ),
        AppCommand.focusSearch => Keybinding(
          LogicalKeyboardKey.keyF,
          control: !mac,
          meta: mac,
        ),
      };
}

abstract interface class KeybindingsStore {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesKeybindingsStore implements KeybindingsStore {
  static const key = 'crm.keybindings.v1';
  @override
  Future<String?> read() => SharedPreferencesAsync().getString(key);
  @override
  Future<void> write(String value) =>
      SharedPreferencesAsync().setString(key, value);
}

class KeybindingsController extends ChangeNotifier {
  KeybindingsController({KeybindingsStore? store, bool? mac})
    : _store = store ?? PreferencesKeybindingsStore(),
      mac = mac ?? (defaultTargetPlatform == TargetPlatform.macOS);
  final KeybindingsStore _store;
  final bool mac;
  Map<AppCommand, Keybinding> _overrides = {};
  bool saving = false;
  bool loading = false;
  bool _disposed = false;
  String? warning;

  Keybinding binding(AppCommand command) =>
      _overrides[command] ?? Keybinding.standard(command, mac: mac);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _validate(Map<AppCommand, Keybinding> overrides) {
    final bindings = <AppCommand, Keybinding>{
      for (final command in AppCommand.values)
        command: overrides[command] ?? Keybinding.standard(command, mac: mac),
    };
    for (final entry in bindings.entries) {
      entry.value.validate();
      for (final other in bindings.entries) {
        if (entry.key != other.key &&
            entry.key.overlaps(other.key) &&
            entry.value.conflictsWith(other.value)) {
          throw KeybindingException(
            'Это сочетание уже назначено: «${other.key.label}».',
          );
        }
      }
    }
  }

  Future<void> load() async {
    loading = true;
    _notify();
    try {
      final text = await _store.read();
      if (_disposed) return;
      if (text != null) {
        final data = jsonDecode(text);
        if (data is! Map || data['version'] != 1 || data['bindings'] is! Map) {
          throw const FormatException('Invalid keybindings settings');
        }
        final overrides = <AppCommand, Keybinding>{};
        for (final entry in (data['bindings'] as Map).entries) {
          final command = AppCommand.values
              .where((item) => item.id == entry.key)
              .firstOrNull;
          if (command == null) throw const FormatException('Unknown command');
          overrides[command] = Keybinding.fromJson(entry.value);
        }
        _validate(overrides);
        _overrides = overrides;
      }
      warning = null;
    } on FormatException {
      warning = 'Настройки сочетаний повреждены. Используются стандартные.';
    } on KeybindingException {
      warning =
          'В сохранённых сочетаниях есть конфликт. Используются стандартные.';
    } on PlatformException {
      warning = 'Не удалось прочитать сочетания. Используются стандартные.';
    } on TypeError {
      warning = 'Некорректный формат настроек сочетаний.';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> setBinding(AppCommand command, Keybinding? value) async {
    final next = Map<AppCommand, Keybinding>.of(_overrides);
    if (value == null) {
      next.remove(command);
    } else {
      next[command] = value;
    }
    await _save(next);
  }

  Future<void> reset() => _save({});

  void validateBinding(AppCommand command, Keybinding value) {
    _validate({..._overrides, command: value});
  }

  Future<void> _save(Map<AppCommand, Keybinding> next) async {
    if (saving || loading) {
      throw const KeybindingException('Дождитесь сохранения настроек.');
    }
    _validate(next);
    saving = true;
    _notify();
    try {
      await _store.write(
        jsonEncode({
          'version': 1,
          'bindings': {
            for (final entry in next.entries)
              entry.key.id: entry.value.toJson(),
          },
        }),
      );
      if (_disposed) return;
      _overrides = next;
      warning = null;
    } on PlatformException {
      throw const KeybindingException(
        'Не удалось сохранить сочетание. Прежние настройки не изменены.',
      );
    } finally {
      saving = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
