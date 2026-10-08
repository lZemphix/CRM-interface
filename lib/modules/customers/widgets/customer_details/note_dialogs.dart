import 'package:flutter/material.dart';

import '../../models/customer_note.dart';
import '../../repos/customers_repository.dart';

class CustomerNoteEditor extends StatefulWidget {
  const CustomerNoteEditor({super.key, this.note, required this.onSave});

  final CustomerNote? note;
  final Future<CustomerNote> Function(String text) onSave;

  @override
  State<CustomerNoteEditor> createState() => _CustomerNoteEditorState();
}

class _CustomerNoteEditorState extends State<CustomerNoteEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _text;
  bool _saving = false;
  bool _refreshRequired = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.note?.text ?? '');
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _refreshRequired || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final note = await widget.onSave(
        _text.text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim(),
      );
      if (mounted) Navigator.of(context).pop(note);
    } on CustomerRequestException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _refreshRequired = error.refreshRequired;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        widget.note == null ? 'Новая заметка' : 'Редактировать заметку',
      ),
      scrollable: true,
      content: SizedBox(
        width: 500,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('customer-note-text'),
                controller: _text,
                autofocus: true,
                readOnly: _saving,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Текст заметки',
                  border: OutlineInputBorder(),
                  helperText: 'До 4000 символов',
                ),
                validator: (value) {
                  final text = (value ?? '')
                      .replaceAll('\r\n', '\n')
                      .replaceAll('\r', '\n')
                      .trim();
                  if (text.isEmpty) return 'Введите текст заметки';
                  if (text.runes.length > 4000) {
                    return 'Не больше 4000 символов';
                  }
                  return null;
                },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_refreshRequired)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Скопируйте нужный текст, закройте форму и обновите заметки перед повторной попыткой.',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving || _refreshRequired ? null : _save,
          child: Text(_saving ? 'Сохранение…' : 'Сохранить'),
        ),
      ],
    ),
  );
}

class ArchiveCustomerNoteDialog extends StatefulWidget {
  const ArchiveCustomerNoteDialog({super.key, required this.onArchive});
  final Future<void> Function() onArchive;

  @override
  State<ArchiveCustomerNoteDialog> createState() =>
      _ArchiveCustomerNoteDialogState();
}

class _ArchiveCustomerNoteDialogState extends State<ArchiveCustomerNoteDialog> {
  bool _saving = false;
  bool _refreshRequired = false;
  String? _error;

  Future<void> _archive() async {
    if (_saving || _refreshRequired) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onArchive();
      if (mounted) Navigator.of(context).pop(true);
    } on CustomerRequestException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _refreshRequired = error.refreshRequired;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Архивировать заметку?'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Заметка исчезнет из карточки клиента. На сервере запись и история изменений сохранятся.',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_refreshRequired)
            const Text('Закройте окно и обновите список заметок.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving || _refreshRequired ? null : _archive,
          child: Text(_saving ? 'Архивирование…' : 'Архивировать'),
        ),
      ],
    ),
  );
}
