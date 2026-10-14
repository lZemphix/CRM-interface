import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../core/api_client/endpoint.dart';
import '../core/connection/server_probe.dart';
import '../core/connection/server_settings_form.dart';
import '../core/settings/server_settings.dart';
import 'app_runtime.dart';

/// Owns the server selection and its entire dependency graph, not business data.
class ServerApp extends StatefulWidget {
  const ServerApp({
    super.key,
    required this.arguments,
    this.settings,
    this.probe,
    this.createRuntime,
    this.compiledUrl = ApiEndpoint.configuredUrl,
  });
  final List<String> arguments;
  final ServerSettingsStore? settings;
  final ServerProbe? probe;
  final AppRuntime Function(String)? createRuntime;
  final String compiledUrl;
  @override
  State<ServerApp> createState() => _ServerAppState();
}

class _ServerAppState extends State<ServerApp> {
  late final _settings = widget.settings ?? PreferencesServerSettings();
  late final _probe = widget.probe ?? ServerProbe();
  AppRuntime? _runtime;
  AppRuntime? _pendingRuntime;
  bool _loading = true;
  bool _configuring = false;
  String? _notice;
  String? _override;
  AppRuntime _create(String url) =>
      (widget.createRuntime ?? AppRuntime.new)(url);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    String? url;
    try {
      _override = ApiEndpoint.argumentOverride(widget.arguments);
      if (_override != null) {
        url = _override;
      } else {
        final saved = await _settings.read();
        url = saved ?? (widget.compiledUrl.isEmpty ? null : widget.compiledUrl);
      }
      if (url != null) url = ApiEndpoint.validate(url);
    } on FormatException {
      _notice = 'Настроенный адрес некорректен. Укажите адрес сервера заново.';
      url = null;
    } on ServerSettingsException {
      _notice = 'Не удалось прочитать настройки. Адрес можно указать заново.';
    }
    if (!mounted) return;
    setState(() {
      _runtime = url == null ? null : _create(url);
      _loading = false;
    });
  }

  Future<void> _save(String url) async {
    // Never activate a different server before clearing the previous session.
    await _runtime?.retire();
    if (!mounted) return;
    final candidate = _create(url);
    try {
      await candidate.client.sessionStore.delete();
      await candidate.client.sessionStore.clearLegacyToken();
      await _settings.write(url);
      if (!mounted) {
        await candidate.close();
        return;
      }
      _pendingRuntime = candidate;
    } on Object {
      await candidate.close();
      rethrow;
    }
  }

  void _activatePending() {
    final old = _runtime;
    setState(() {
      _runtime = _pendingRuntime;
      _pendingRuntime = null;
      _notice = null;
    });
    if (old != null) unawaited(old.close());
  }

  Future<void> _configure(BuildContext context) async {
    if (_configuring) return;
    _configuring = true;
    final previous = _runtime!;
    try {
      await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ServerSettingsForm(
                initialUrl: previous.url,
                notice:
                    'После сохранения потребуется войти заново.'
                    '${_override == null ? '' : ' Аргумент --api-url снова переопределит адрес при следующем запуске.'}',
                probe: _probe,
                onSave: _save,
                onSaved: (url) => Navigator.of(dialogContext).pop(url),
                onCancel: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (_pendingRuntime != null) {
        _activatePending();
      } else if (previous.retired) {
        // A storage failure can occur after requests were stopped. Cancelling
        // must return to a fresh client, not leave login connected to dead Dio.
        setState(() => _runtime = _create(previous.url));
        unawaited(previous.close());
      }
    } finally {
      _configuring = false;
    }
  }

  @override
  void dispose() {
    final runtime = _runtime;
    final pending = _pendingRuntime;
    if (runtime != null) unawaited(runtime.close());
    if (pending != null) unawaited(pending.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _runtime;
    if (runtime != null) {
      // Disposes old navigation, auth subscriptions, screens and module state.
      return MyApp(
        key: ObjectKey(runtime),
        authRepository: runtime.auth,
        modules: runtime.modules,
        serverUrl: runtime.url,
        onConfigureServer: _configure,
      );
    }
    return CrmAppFrame(
      home: Scaffold(
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: ServerSettingsForm(
                      notice: _notice,
                      probe: _probe,
                      onSave: _save,
                      onSaved: (_) => _activatePending(),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
