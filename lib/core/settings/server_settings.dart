import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client/endpoint.dart';

abstract interface class ServerSettingsStore {
  Future<String?> read();
  Future<void> write(String url);
}

class ServerSettingsException implements Exception {
  const ServerSettingsException();
}

/// Ordinary preferences only. Passwords and tokens do not belong here.
class PreferencesServerSettings implements ServerSettingsStore {
  PreferencesServerSettings({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  static const key = 'crm.backend_url';

  @override
  Future<String?> read() async {
    try {
      return await _preferences.getString(key);
    } on PlatformException {
      throw const ServerSettingsException();
    } on TypeError {
      throw const ServerSettingsException();
    }
  }

  @override
  Future<void> write(String url) async {
    final normalized = ApiEndpoint.validate(url);
    try {
      await _preferences.setString(key, normalized);
    } on PlatformException {
      throw const ServerSettingsException();
    }
  }
}
