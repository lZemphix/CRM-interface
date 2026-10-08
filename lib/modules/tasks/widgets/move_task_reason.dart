import 'package:flutter/material.dart';

/// Сервер требует причину при переходе на доработку или закрытии задачи.
Future<String?> askTaskMoveReason(BuildContext context) {
  final formKey = GlobalKey<FormState>();
  var reason = '';
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
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
          onPressed: () => Navigator.of(context).pop(),
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
  );
}
