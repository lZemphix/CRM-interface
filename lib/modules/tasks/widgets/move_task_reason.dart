import 'package:flutter/material.dart';
import 'package:crm_interface/core/keyboard/dialog_keyboard_scope.dart';

/// Сервер требует причину при переходе на доработку или закрытии задачи.
Future<String?> askTaskMoveReason(BuildContext context) {
  final formKey = GlobalKey<FormState>();
  final keyboard = GlobalKey<DialogKeyboardScopeState>();
  var reason = '';
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => DialogKeyboardScope(
      key: keyboard,
      hasChanges: () => reason.isNotEmpty,
      onSubmit: () {
        if (formKey.currentState!.validate()) Navigator.of(context).pop(reason);
      },
      child: AlertDialog(
        title: const Text('Причина переноса'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: TextFormField(
              autofocus: true,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Причина *'),
              onChanged: (value) => reason = value.trim(),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Укажите причину'
                  : null,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => keyboard.currentState?.requestClose(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(reason);
              }
            },
            child: const Text('Перенести'),
          ),
        ],
      ),
    ),
  );
}
