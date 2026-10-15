import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client/endpoint.dart';
import '../settings/server_settings.dart';
import 'server_probe.dart';
import '../keyboard/command_scope.dart';
import '../keyboard/dialog_keyboard_scope.dart';
import '../keyboard/keybindings.dart';

class ServerSettingsForm extends StatefulWidget {
  const ServerSettingsForm({
    super.key,
    required this.probe,
    required this.onSave,
    required this.onSaved,
    this.initialUrl = '',
    this.notice,
    this.onCancel,
  });
  final ServerProbe probe;
  final Future<void> Function(String url) onSave;
  final ValueChanged<String> onSaved;
  final String initialUrl;
  final String? notice;
  final VoidCallback? onCancel;

  @override
  State<ServerSettingsForm> createState() => _ServerSettingsFormState();
}

class _ServerSettingsFormState extends State<ServerSettingsForm> {
  final _form = GlobalKey<FormState>();
  final _keyboard = GlobalKey<DialogKeyboardScopeState>();
  late final _address = TextEditingController(text: widget.initialUrl);
  bool _busy = false;
  bool _allowHttp = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final url = ApiEndpoint.validate(_address.text);
    if (Uri.parse(url).scheme == 'http' && !_allowHttp) {
      setState(() => _error = 'Подтвердите использование незащищённого HTTP.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.probe.check(url);
      if (!mounted) return;
      await widget.onSave(url);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onSaved(url);
    } on ServerConnectionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on ServerSettingsException {
      if (mounted) {
        setState(
          () =>
              _error = 'Не удалось сохранить адрес сервера. Повторите попытку.',
        );
      }
    } on PlatformException {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось очистить защищённое хранилище. '
              'Сервер не изменён. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = PopScope(
      canPop: !_busy,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Text(
              'Подключение к серверу',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Введите адрес CRM, который выдал администратор компании.',
            ),
            if (widget.notice != null) Text(widget.notice!),
            TextFormField(
              key: const Key('server-address'),
              autofocus: true,
              controller: _address,
              enabled: !_busy,
              autocorrect: false,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {
                _allowHttp = false;
                _error = null;
              }),
              decoration: const InputDecoration(
                labelText: 'Адрес сервера',
                hintText: 'https://crm.company.ru',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                try {
                  ApiEndpoint.validate(value ?? '');
                  return null;
                } on FormatException catch (error) {
                  return error.message;
                }
              },
            ),
            if (Uri.tryParse(_address.text.trim())?.scheme == 'http')
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _allowHttp,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _allowHttp = value ?? false),
                title: const Text(
                  'Разрешить HTTP для локальной сети / разработки',
                ),
                subtitle: const Text(
                  'HTTP не шифрует пароль и токены. Для рабочего сервера используйте HTTPS.',
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('server-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onCancel != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _keyboard.currentState?.requestClose(),
                    child: const Text('Отмена'),
                  ),
                FilledButton(
                  key: const Key('save-server'),
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Проверяем…' : 'Проверить и сохранить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (widget.onCancel != null) {
      return DialogKeyboardScope(
        key: _keyboard,
        busy: _busy,
        hasChanges: () => _address.text.trim() != widget.initialUrl.trim(),
        onSubmit: _save,
        onClose: widget.onCancel,
        child: form,
      );
    }
    return CommandScope(commands: {AppCommand.submitForm: _save}, child: form);
  }
}
