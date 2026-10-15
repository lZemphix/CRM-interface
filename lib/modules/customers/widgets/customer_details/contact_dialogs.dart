import 'package:flutter/material.dart';

import '../../../../core/keyboard/dialog_keyboard_scope.dart';
import '../../models/customer.dart';
import '../../models/update_customer.dart';
import '../../repos/customers_repository.dart';

String contactTypeLabel(ContactType type) => switch (type) {
  ContactType.phone => 'Телефон',
  ContactType.email => 'Email',
  ContactType.telegram => 'Telegram',
  ContactType.max => 'MAX',
  ContactType.other => 'Другой',
  ContactType.unknown => 'Неизвестный тип',
};

class CustomerContactsWindow extends StatefulWidget {
  const CustomerContactsWindow({
    super.key,
    required this.customer,
    required this.repository,
    required this.onChanged,
  });
  final CustomerDetails customer;
  final CustomersRepository repository;
  final VoidCallback onChanged;
  @override
  State<CustomerContactsWindow> createState() => _CustomerContactsWindowState();
}

class _CustomerContactsWindowState extends State<CustomerContactsWindow> {
  final _keyboard = GlobalKey<DialogKeyboardScopeState>();
  late List<CustomerContact> _contacts;
  bool _working = false;
  bool _dialogOpen = false;
  bool _needsReload = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contacts = widget.customer.contacts;
  }

  void _changed() {
    _needsReload = true;
    widget.onChanged();
  }

  Future<void> _reload() async {
    setState(() => _working = true);
    try {
      final fresh = await widget.repository.getCustomerDetails(
        id: widget.customer.id,
      );
      if (mounted) {
        setState(() {
          _contacts = fresh.contacts;
          _needsReload = false;
          _error = null;
        });
      }
    } on CustomerRequestException catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '${error.message}\nНе удалось обновить контакты. Повторите загрузку.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _edit([CustomerContact? contact]) async {
    if (_working || _needsReload) return;
    setState(() {
      _working = true;
      _dialogOpen = true;
      _error = null;
    });
    try {
      await showDialog<CustomerContact>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CustomerContactEditor(
          contact: contact,
          onRefreshRequired: _changed,
          onSave: (request) async {
            final result = contact == null
                ? await widget.repository.addContact(
                    widget.customer.id,
                    request,
                  )
                : await widget.repository.updateContact(
                    widget.customer.id,
                    contact.id,
                    request,
                    version: contact.version!,
                  );
            _changed();
            return result;
          },
        ),
      );
      if (mounted) setState(() => _dialogOpen = false);
      if (mounted && _needsReload) await _reload();
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _dialogOpen = false;
        });
      }
    }
  }

  Future<void> _archive(CustomerContact contact) async {
    if (_working || _needsReload) return;
    setState(() {
      _working = true;
      _dialogOpen = true;
      _error = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => DialogKeyboardScope(
          child: AlertDialog(
            title: const Text('Архивировать контакт?'),
            content: Text(
              '${contactTypeLabel(contact.type)}: ${contact.value}\n'
              'Контакт исчезнет из карточки. История сохранится.',
            ),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Архивировать'),
              ),
            ],
          ),
        ),
      );
      if (mounted) setState(() => _dialogOpen = false);
      if (confirmed != true || !mounted) return;
      try {
        await widget.repository.archiveContact(widget.customer.id, contact.id);
        _changed();
      } on CustomerRequestException catch (error) {
        if (error.refreshRequired) _changed();
        if (mounted) setState(() => _error = error.message);
      }
      if (mounted && _needsReload) await _reload();
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _dialogOpen = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => DialogKeyboardScope(
    key: _keyboard,
    busy: _working,
    child: AlertDialog(
      title: const Text('Контакты клиента'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              const Text(
                'Каждый контакт сохраняется отдельно. У клиента должен оставаться основной телефон или email.',
              ),
              if (_working && !_dialogOpen) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_needsReload)
                TextButton(
                  onPressed: _working ? null : _reload,
                  child: const Text('Повторить загрузку контактов'),
                ),
              if (_contacts.isEmpty) const Text('Контакты не указаны'),
              for (final contact in _contacts)
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.value,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${contactTypeLabel(contact.type)}${contact.isPrimary ? ' · Основной' : ''}'
                                '${contact.label == null ? '' : ' · ${contact.label}'}',
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Изменить контакт',
                          onPressed: _working || _needsReload
                              ? null
                              : () => _edit(contact),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Архивировать контакт',
                          onPressed: _working || _needsReload
                              ? null
                              : () => _archive(contact),
                          icon: const Icon(Icons.archive_outlined, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _working
              ? null
              : () => _keyboard.currentState?.requestClose(),
          child: const Text('Закрыть'),
        ),
        FilledButton(
          onPressed: _working || _needsReload ? null : () => _edit(),
          child: const Text('Добавить контакт'),
        ),
      ],
    ),
  );
}

class CustomerContactEditor extends StatefulWidget {
  const CustomerContactEditor({
    super.key,
    this.contact,
    required this.onSave,
    required this.onRefreshRequired,
  });
  final CustomerContact? contact;
  final Future<CustomerContact> Function(WriteCustomerContactRequest) onSave;
  final VoidCallback onRefreshRequired;
  @override
  State<CustomerContactEditor> createState() => _CustomerContactEditorState();
}

class _CustomerContactEditorState extends State<CustomerContactEditor> {
  final _form = GlobalKey<FormState>();
  final _keyboard = GlobalKey<DialogKeyboardScopeState>();
  late final TextEditingController _value;
  late final TextEditingController _label;
  late ContactType _type;
  late bool _primary;
  bool _saving = false;
  bool _blocked = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _value = TextEditingController(text: contact?.value ?? '');
    _label = TextEditingController(text: contact?.label ?? '');
    _type = contact?.type ?? ContactType.phone;
    _primary = contact?.isPrimary ?? false;
    if (contact != null &&
        (contact.version == null ||
            contact.version! < 1 ||
            contact.type == ContactType.unknown)) {
      _blocked = true;
      _error = 'Сервер не вернул версию или тип контакта не поддерживается. Обновите карточку или backend.';
    }
  }

  @override
  void dispose() {
    _value.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _blocked || !_form.currentState!.validate()) return;
    final value = _value.text.trim();
    final label = _label.text.trim().isEmpty ? null : _label.text.trim();
    final old = widget.contact;
    if (old != null &&
        value == old.value &&
        label == old.label &&
        _primary == old.isPrimary) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final contact = await widget.onSave(
        WriteCustomerContactRequest(
          type: _type,
          value: value,
          label: label,
          isPrimary: _primary,
        ),
      );
      if (mounted) Navigator.of(context).pop(contact);
    } on CustomerRequestException catch (error) {
      if (error.refreshRequired) widget.onRefreshRequired();
      if (mounted) {
        setState(() {
          _error = error.message;
          _blocked = error.refreshRequired;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => DialogKeyboardScope(
    key: _keyboard,
    busy: _saving,
    hasChanges: () => _dirty,
    onSubmit: _save,
    child: AlertDialog(
      title: Text(
        widget.contact == null ? 'Добавить контакт' : 'Изменить контакт',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            onChanged: () => _dirty = true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                DropdownButtonFormField<ContactType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Тип контакта'),
                  items: [
                    for (final type in ContactType.values)
                      if (type != ContactType.unknown || type == _type)
                        DropdownMenuItem(
                          value: type,
                          child: Text(contactTypeLabel(type)),
                        ),
                  ],
                  onChanged: widget.contact != null || _saving
                      ? null
                      : (type) => setState(() => _type = type!),
                ),
                TextFormField(
                  key: const Key('contact-value'),
                  controller: _value,
                  autofocus: true,
                  enabled: !_saving,
                  maxLength: 320,
                  decoration: InputDecoration(
                    labelText: 'Значение',
                    hintText: _type == ContactType.phone ? '+7…' : null,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Введите контакт'
                      : null,
                ),
                TextFormField(
                  key: const Key('contact-label'),
                  controller: _label,
                  enabled: !_saving,
                  maxLength: 64,
                  decoration: const InputDecoration(
                    labelText: 'Подпись (необязательно)',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Основной контакт этого типа'),
                  value: _primary,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _primary = value!;
                          _dirty = true;
                        }),
                ),
                const Text(
                  'При выборе основного предыдущий основной контакт того же типа станет запасным.',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => _keyboard.currentState?.requestClose(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving || _blocked ? null : _save,
          child: Text(_saving ? 'Сохраняем…' : 'Сохранить'),
        ),
      ],
    ),
  );
}
