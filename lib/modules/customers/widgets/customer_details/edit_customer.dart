import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/keyboard/dialog_keyboard_scope.dart';
import '../../../../core/theme/app_palette.dart';
import '../../models/create_customer.dart';
import '../../models/customer.dart';
import '../../models/update_customer.dart';
import '../../repos/customers_repository.dart';

class EditCustomerWindow extends StatefulWidget {
  const EditCustomerWindow({
    super.key,
    required this.customer,
    required this.options,
    required this.onSave,
    required this.onRefreshRequired,
  });
  final CustomerDetails customer;
  final CustomerEditOptions options;
  final Future<UpdatedCustomerResponse> Function(UpdateCustomerRequest) onSave;
  final VoidCallback onRefreshRequired;

  @override
  State<EditCustomerWindow> createState() => _EditCustomerWindowState();
}

class _EditCustomerWindowState extends State<EditCustomerWindow> {
  final _form = GlobalKey<FormState>();
  final _keyboard = GlobalKey<DialogKeyboardScopeState>();
  late final TextEditingController _name;
  late final TextEditingController _birthday;
  CustomerGender? _gender;
  bool _genderTouched = false;
  int? _branch;
  int? _responsible;
  bool _saving = false;
  bool _blocked = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer.fullName);
    _birthday = TextEditingController(
      text: customer.dateOfBirth == null
          ? ''
          : DateFormat('dd.MM.yyyy').format(customer.dateOfBirth!),
    );
    _gender = CustomerGender.values
        .where((g) => g.name == customer.gender)
        .firstOrNull;
    _branch = customer.homeBranchId;
    _responsible = customer.responsibleEmployeeId;
    if (customer.version == null || customer.version! < 1) {
      _blocked = true;
      _error =
          'Сервер не вернул версию клиента. Обновите карточку или backend.';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _birthday.dispose();
    super.dispose();
  }

  DateTime? _date() {
    try {
      return DateFormat('dd.MM.yyyy').parseStrict(_birthday.text.trim());
    } on FormatException {
      return null;
    }
  }

  String? _validateDate(String? text) {
    if (text?.trim().isEmpty ?? true) {
      return widget.customer.dateOfBirth == null
          ? null
          : 'Дату рождения нельзя очистить';
    }
    final date = _date();
    if (date == null || date.year < 1) {
      return 'Укажите дату в формате дд.мм.гггг';
    }
    if (date.isAfter(DateTime.now())) {
      return 'Дата рождения не может быть в будущем';
    }
    return null;
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _date();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(1),
      lastDate: today,
      initialDate: current != null && !current.isAfter(today) ? current : today,
    );
    if (mounted && date != null) {
      _birthday.text = DateFormat('dd.MM.yyyy').format(date);
      _dirty = true;
    }
  }

  Future<void> _save() async {
    if (_saving || _blocked || !_form.currentState!.validate()) return;
    final original = widget.customer;
    final name = _name.text.trim();
    final date = _date();
    final request = UpdateCustomerRequest(
      version: original.version!,
      fullName: name == original.fullName ? null : name,
      dateOfBirth: date == original.dateOfBirth ? null : date,
      gender: !_genderTouched || _gender?.name == original.gender
          ? null
          : CustomerFieldChange(_gender),
      homeBranchId: _branch == original.homeBranchId
          ? null
          : CustomerFieldChange(_branch),
      responsibleEmployeeId: _responsible == original.responsibleEmployeeId
          ? null
          : CustomerFieldChange(_responsible),
    );
    if (request.toApi().length == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.onSave(request);
      if (mounted) Navigator.of(context).pop(result);
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

  List<DropdownMenuItem<int>> _options(
    List<CustomerFormOption> options,
    int? selected,
    String missingLabel,
  ) => [
    const DropdownMenuItem<int>(child: Text('Не выбран')),
    for (final option in options)
      DropdownMenuItem(
        value: option.id,
        child: Text(option.name, overflow: TextOverflow.ellipsis),
      ),
    if (selected != null && !options.any((o) => o.id == selected))
      DropdownMenuItem(value: selected, child: Text(missingLabel)),
  ];

  @override
  Widget build(BuildContext context) => DialogKeyboardScope(
    key: _keyboard,
    busy: _saving,
    hasChanges: () => _dirty,
    onSubmit: _save,
    child: AlertDialog(
      title: const Text('О клиенте — изменить'),
      content: SizedBox(
        width: 480,
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
                TextFormField(
                  key: const Key('edit-customer-name'),
                  controller: _name,
                  autofocus: true,
                  enabled: !_saving,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    labelText: 'ФИО',
                    counterText: '',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Введите ФИО'
                      : null,
                ),
                DropdownButtonFormField<CustomerGender>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: 'Пол'),
                  items: const [
                    DropdownMenuItem(child: Text('Не указан')),
                    DropdownMenuItem(
                      value: CustomerGender.female,
                      child: Text('Женский'),
                    ),
                    DropdownMenuItem(
                      value: CustomerGender.male,
                      child: Text('Мужской'),
                    ),
                    DropdownMenuItem(
                      value: CustomerGender.other,
                      child: Text('Другой'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _gender = value;
                          _genderTouched = true;
                        }),
                ),
                TextFormField(
                  key: const Key('edit-customer-birthday'),
                  controller: _birthday,
                  enabled: !_saving,
                  validator: _validateDate,
                  decoration: InputDecoration(
                    labelText: 'Дата рождения',
                    hintText: 'дд.мм.гггг',
                    suffixIcon: IconButton(
                      onPressed: _saving ? null : _pickBirthday,
                      tooltip: 'Выбрать дату рождения',
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _branch,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Предпочитаемый филиал',
                  ),
                  items: _options(
                    widget.options.branches,
                    _branch,
                    'Филиал #$_branch (недоступен)',
                  ),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _branch = value),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _responsible,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Ответственный'),
                  items: _options(
                    widget.options.employees,
                    _responsible,
                    widget.customer.responsible?.fullName ??
                        'Сотрудник #$_responsible (недоступен)',
                  ),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _responsible = value),
                ),
                Text(
                  'Источник, способ регистрации и создавший сотрудник — история появления клиента; здесь они не меняются.',
                  style: TextStyle(
                    color: context.colors.textMutted,
                    fontSize: 12,
                  ),
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
