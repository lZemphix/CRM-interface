import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ThemeSettingsStore {
  Future<String?> read();
  Future<void> write(String theme);
}

class ThemeSettingsException implements Exception {
  const ThemeSettingsException();
}

class PreferencesThemeSettings implements ThemeSettingsStore {
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _storage =>
      _preferences ??= SharedPreferencesAsync();
  static const key = 'crm.appearance.theme.v1';
  @override
  Future<String?> read() async {
    try {
      return await _storage.getString(key);
    } on PlatformException {
      throw const ThemeSettingsException();
    } on MissingPluginException {
      throw const ThemeSettingsException();
    } on TypeError {
      throw const ThemeSettingsException();
    } on StateError {
      throw const ThemeSettingsException();
    }
  }

  @override
  Future<void> write(String theme) async {
    try {
      await _storage.setString(key, theme);
    } on PlatformException {
      throw const ThemeSettingsException();
    } on MissingPluginException {
      throw const ThemeSettingsException();
    } on StateError {
      throw const ThemeSettingsException();
    }
  }
}

class ThemeController extends ChangeNotifier {
  ThemeController({ThemeSettingsStore? store})
    : _store = store ?? PreferencesThemeSettings();
  final ThemeSettingsStore _store;
  ThemeMode mode = ThemeMode.light;
  bool loaded = false;
  bool saving = false;
  String? warning;
  Future<void>? _loading;
  bool _disposed = false;

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      final value = await _store.read();
      if (_disposed) return;
      mode = value == 'dark' ? ThemeMode.dark : ThemeMode.light;
      if (value != null && value != 'dark' && value != 'light') {
        warning = 'Сохранённая тема неизвестна. Выбрана светлая.';
      }
    } on ThemeSettingsException {
      if (_disposed) return;
      warning = 'Не удалось прочитать настройку темы. Выбрана светлая.';
    } finally {
      if (!_disposed) {
        loaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> setMode(ThemeMode value) async {
    if (_disposed || !loaded || saving || value == ThemeMode.system) return;
    if (value == mode && warning == null) return;
    mode = value;
    saving = true;
    warning = null;
    notifyListeners();
    try {
      await _store.write(value.name);
    } on ThemeSettingsException {
      if (!_disposed) warning = 'Тема применена, но сохранить выбор не удалось. После перезапуска он может сброситься.';
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ThemeSettingsScope extends InheritedNotifier<ThemeController> {
  const ThemeSettingsScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);
  static ThemeController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ThemeSettingsScope>()
      ?.notifier;
}
