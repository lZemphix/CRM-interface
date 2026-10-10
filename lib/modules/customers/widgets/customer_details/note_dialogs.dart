import 'package:flutter/material.dart';

import '../../models/customer_note.dart';
import '../../repos/customers_repository.dart';
import '../../../../core/theme/light/colorscheme.dart';

class CustomerNoteEditor extends StatefulWidget {
  const CustomerNoteEditor({
    super.key,
    this.note,
    required this.onSave,
    this.inline = false,
    this.onSaved,
    this.onSavingChanged,
    this.refreshRequired = false,
    this.enabled = true,
  }) : assert(!inline || onSaved != null);

  final CustomerNote? note;
  final Future<CustomerNote> Function(String text) onSave;
  final bool inline;
  final ValueChanged<CustomerNote>? onSaved;
  final ValueChanged<bool>? onSavingChanged;
  final bool refreshRequired;
  final bool enabled;

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

  @override
  void didUpdateWidget(covariant CustomerNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRequired && !widget.refreshRequired) {
      _refreshRequired = false;
      _error = null;
    }
  }

  Future<void> _save() async {
    if (_saving ||
        !widget.enabled ||
        _refreshRequired ||
        widget.refreshRequired ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    widget.onSavingChanged?.call(true);
    try {
      final note = await widget.onSave(
        _text.text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim(),
      );
      if (!mounted) return;
      if (widget.inline) {
        _form.currentState!.reset();
        _text.clear();
        widget.onSaved!(note);
      } else {
        Navigator.of(context).pop(note);
      }
    } on CustomerRequestException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _refreshRequired = error.refreshRequired;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        widget.onSavingChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.inline
      ? _inlineComposer()
      : PopScope(
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

  Widget _inlineComposer() {
    final field = TextFormField(
      key: const ValueKey('customer-note-text'),
      controller: _text,
      enabled: !_saving && widget.enabled,
      minLines: 3,
      maxLines: 5,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Добавить рабочую заметку...',
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? Colors.white
              : AppColors.background,
        ),
        constraints: const BoxConstraints(minHeight: 84),
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.notActiveBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.notActiveBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.activeElement),
        ),
      ),
      validator: (value) {
        final text = (value ?? '')
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .trim();
        if (text.isEmpty) return 'Введите текст заметки';
        if (text.runes.length > 4000) return 'Не больше 4000 символов';
        return null;
      },
    );
    final save = FilledButton(
      onPressed:
          _saving ||
              !widget.enabled ||
              _refreshRequired ||
              widget.refreshRequired
          ? null
          : _save,
      style:
          FilledButton.styleFrom(
            backgroundColor: AppColors.activeElement,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.notActiveBorder;
              }
              return states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.pressed)
                  ? AppColors.activeElementHover
                  : AppColors.activeElement;
            }),
          ),
      child: Text(_saving ? 'Сохранение…' : 'Сохранить'),
    );
    return PopScope(
      canPop: !_saving,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (_, constraints) => constraints.maxWidth < 440
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        field,
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerRight, child: save),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: field),
                        const SizedBox(width: 10),
                        save,
                      ],
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_refreshRequired)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Обновите заметки перед повторной попыткой. Черновик сохранён в поле ввода.',
                ),
              ),
          ],
        ),
      ),
    );
  }
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
