import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/light/colorscheme.dart';
import '../models/create_customer.dart';
import '../models/customer.dart';
import '../repos/customers_repository.dart';

class CreateCustomerWindow extends StatefulWidget {
  const CreateCustomerWindow({
    super.key,
    required this.loadOptions,
    required this.onCreate,
  });

  final Future<CustomerCreationOptions> Function() loadOptions;
  final Future<CreatedCustomerResponse> Function(CreateCustomerRequest)
  onCreate;

  @override
  State<CreateCustomerWindow> createState() => _CreateCustomerWindowState();
}

class _CreateCustomerWindowState extends State<CreateCustomerWindow> {
  final _formKey = GlobalKey<FormState>();
  final _birthdayController = TextEditingController();
  CustomerCreationOptions? _options;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _saveError;
  String _name = '';
  String _phone = '';
  String _email = '';
  CustomerGender? _gender;
  int? _sourceId;
  int? _branchId;
  int? _employeeId;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final options = await widget.loadOptions();
      if (mounted) setState(() => _options = options);
    } on CustomerRequestException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DateTime? _birthday() {
    final text = _birthdayController.text.trim();
    if (!RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(text)) return null;
    try {
      final date = DateFormat('dd.MM.yyyy').parseStrict(text);
      return date.year >= 1 ? date : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _birthday();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(1),
      lastDate: today,
      initialDate: current != null && !current.isAfter(today) ? current : today,
      helpText: 'Дата рождения',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (mounted && date != null) {
      _birthdayController.text = DateFormat('dd.MM.yyyy').format(date);
    }
  }

  Future<void> _submit() async {
    if (_isSaving || _isLoading || _options?.sources.isNotEmpty != true) return;
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final customer = await widget.onCreate(
        CreateCustomerRequest(
          fullName: _name,
          dateOfBirth: _birthday()!,
          acquisitionSourceId: _sourceId!,
          gender: _gender,
          homeBranchId: _branchId,
          responsibleEmployeeId: _employeeId,
          contacts: [
            if (_phone.isNotEmpty)
              CreateCustomerContact(type: ContactType.phone, value: _phone),
            if (_email.isNotEmpty)
              CreateCustomerContact(type: ContactType.email, value: _email),
          ],
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(customer);
      }
    } on CustomerRequestException catch (error) {
      if (mounted) setState(() => _saveError = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Новый клиент'),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _saveError!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
        content: SizedBox(width: 480, child: _buildContent()),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.activeElement,
            ),
            onPressed:
                _isSaving || _isLoading || _options?.sources.isNotEmpty != true
                ? null
                : _submit,
            child: Text(_isSaving ? 'Создаём…' : 'Создать'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_loadError!),
          TextButton(onPressed: _loadOptions, child: const Text('Повторить')),
        ],
      );
    }
    final options = _options!;
    if (options.sources.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Нет доступных источников привлечения. Обратитесь к администратору.',
          ),
          TextButton(onPressed: _loadOptions, child: const Text('Повторить')),
        ],
      );
    }
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            _buildPersonalFields(),
            _buildContactFields(),
            _buildAssignmentFields(options),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalFields() {
    return Column(
      spacing: 14,
      children: [
        TextFormField(
          key: const Key('customer-name'),
          autofocus: true,
          enabled: !_isSaving,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: 'ФИО *',
            counterText: '',
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Введите ФИО' : null,
          onSaved: (value) => _name = value!.trim(),
        ),
        TextFormField(
          key: const Key('customer-birthday'),
          controller: _birthdayController,
          enabled: !_isSaving,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            labelText: 'Дата рождения *',
            hintText: 'дд.мм.гггг',
            suffixIcon: IconButton(
              tooltip: 'Выбрать дату',
              onPressed: _isSaving ? null : _pickBirthday,
              icon: const Icon(Icons.calendar_today_outlined),
            ),
          ),
          validator: (_) {
            final date = _birthday();
            if (date == null) return 'Укажите дату в формате дд.мм.гггг';
            if (date.isAfter(DateTime.now())) {
              return 'Дата рождения не может быть в будущем';
            }
            return null;
          },
        ),
        DropdownButtonFormField<CustomerGender>(
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Пол'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Не указан')),
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
          onChanged: _isSaving ? null : (value) => _gender = value,
        ),
      ],
    );
  }

  Widget _buildContactFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        const Text('Укажите телефон или email. Можно заполнить оба.'),
        TextFormField(
          key: const Key('customer-phone'),
          enabled: !_isSaving,
          maxLength: 320,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Телефон',
            hintText: '+7 900 123-45-67',
            counterText: '',
          ),
          onChanged: (value) => _phone = value.trim(),
          onSaved: (value) => _phone = value!.trim(),
          validator: (value) {
            final phone = value?.trim() ?? '';
            if (phone.isEmpty && _email.isEmpty) {
              return 'Укажите телефон или email';
            }
            if (phone.isNotEmpty && !phone.startsWith('+')) {
              return 'Укажите + и код страны';
            }
            return null;
          },
        ),
        TextFormField(
          key: const Key('customer-email'),
          enabled: !_isSaving,
          maxLength: 320,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            counterText: '',
          ),
          onChanged: (value) => _email = value.trim(),
          onSaved: (value) => _email = value!.trim(),
        ),
      ],
    );
  }

  Widget _buildAssignmentFields(CustomerCreationOptions options) {
    return Column(
      spacing: 14,
      children: [
        _buildChoice(
          label: 'Источник привлечения *',
          key: const Key('customer-source'),
          items: options.sources,
          onChanged: (value) => _sourceId = value,
          isRequired: true,
        ),
        _buildChoice(
          label: 'Предпочитаемый филиал',
          key: const Key('customer-branch'),
          items: options.branches,
          onChanged: (value) => _branchId = value,
        ),
        _buildChoice(
          label: 'Ответственный сотрудник',
          key: const Key('customer-employee'),
          items: options.employees,
          onChanged: (value) => _employeeId = value,
        ),
      ],
    );
  }

  Widget _buildChoice({
    Key? key,
    required String label,
    required List<CustomerFormOption> items,
    required ValueChanged<int?> onChanged,
    bool isRequired = false,
  }) {
    return DropdownButtonFormField<int>(
      key: key,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (!isRequired)
          const DropdownMenuItem(value: null, child: Text('Не указан')),
        for (final option in items)
          DropdownMenuItem(
            value: option.id,
            child: Text(option.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _isSaving ? null : onChanged,
      validator: isRequired
          ? (value) => value == null ? 'Выберите источник привлечения' : null
          : null,
    );
  }
}
