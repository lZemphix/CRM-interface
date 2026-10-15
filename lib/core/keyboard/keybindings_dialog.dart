import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'command_scope.dart';
import 'dialog_keyboard_scope.dart';
import 'keybindings.dart';

Future<void> showKeybindingsSettings(BuildContext context) async {
  final controller = KeybindingsScope.maybeOf(context);
  if (controller == null) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => KeybindingsDialog(controller: controller),
  );
}

class KeybindingsDialog extends StatefulWidget {
  const KeybindingsDialog({super.key, required this.controller});
  final KeybindingsController controller;
  @override
  State<KeybindingsDialog> createState() => _KeybindingsDialogState();
}

class _KeybindingsDialogState extends State<KeybindingsDialog> {
  String? _error;
  bool _recording = false;

  Future<void> _edit(AppCommand command) async {
    if (_recording || widget.controller.saving || widget.controller.loading) {
      return;
    }
    setState(() => _recording = true);
    final binding = await showDialog<Keybinding>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _RecordBinding(command: command, controller: widget.controller),
    );
    if (!mounted) return;
    setState(() => _recording = false);
    if (binding != null) {
      await _save(() => widget.controller.setBinding(command, binding));
    }
  }

  Future<void> _save(Future<void> Function() operation) async {
    try {
      await operation();
      if (mounted) setState(() => _error = null);
    } on KeybindingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final busy =
          widget.controller.saving || widget.controller.loading || _recording;
      return DialogKeyboardScope(
        busy: busy,
        child: AlertDialog(
          title: const Text('Горячие клавиши'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  const Text(
                    'Нажмите на сочетание, затем введите новое. '
                    'Изменения сохраняются и применяются сразу. Enter также работает на цифровой клавиатуре.',
                  ),
                  if (widget.controller.warning != null)
                    Text(widget.controller.warning!),
                  for (final command in AppCommand.values)
                    Row(
                      children: [
                        Expanded(child: Text(command.label)),
                        OutlinedButton(
                          key: ValueKey('keybinding-${command.id}'),
                          onPressed: busy ? null : () => _edit(command),
                          child: Text(widget.controller.binding(command).label),
                        ),
                        IconButton(
                          tooltip: 'Стандартное сочетание',
                          key: ValueKey('reset-keybinding-${command.id}'),
                          onPressed: busy
                              ? null
                              : () => _save(
                                  () => widget.controller.setBinding(
                                    command,
                                    null,
                                  ),
                                ),
                          icon: const Icon(Icons.restart_alt, size: 20),
                        ),
                      ],
                    ),
                  const Text(
                    'Команды действуют только в подходящем контексте: '
                    'например, сохранение — в форме, поиск — в открытом разделе. '
                    'Tab и сочетания редактирования текста остаются стандартными.',
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => _save(widget.controller.reset),
              child: const Text('Восстановить все'),
            ),
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    },
  );
}

class _RecordBinding extends StatefulWidget {
  const _RecordBinding({required this.command, required this.controller});
  final AppCommand command;
  final KeybindingsController controller;
  @override
  State<_RecordBinding> createState() => _RecordBindingState();
}

class _RecordBindingState extends State<_RecordBinding> {
  Keybinding? _candidate;
  String? _error;

  KeyEventResult _record(FocusNode node, KeyEvent event) {
    if (!node.hasPrimaryFocus || event.logicalKey == LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent && !Keybinding.isModifier(event.logicalKey)) {
      final candidate = Keybinding.fromEvent(event);
      String? error;
      try {
        candidate.validate();
      } on KeybindingException catch (failure) {
        error = failure.message;
      }
      setState(() {
        _candidate = candidate;
        _error = error;
      });
    }
    // Local recorder only: never a global keyboard hook or OS hotkey.
    return KeyEventResult.handled;
  }

  void _accept() {
    final candidate = _candidate;
    if (candidate == null || _error != null) return;
    try {
      widget.controller.validateBinding(widget.command, candidate);
    } on KeybindingException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    Navigator.of(context).pop(candidate);
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: _record,
    child: AlertDialog(
      title: Text(widget.command.label),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            const Text(
              'Нажмите новое сочетание, затем «Применить». '
              'В этом окне Esc записывается как клавиша; для отмены используйте кнопку.',
            ),
            Text(
              _candidate?.label ?? 'Ожидается нажатие…',
              key: const Key('recorded-keybinding'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('apply-keybinding'),
          onPressed: _candidate == null || _error != null ? null : _accept,
          child: const Text('Применить'),
        ),
      ],
    ),
  );
}
