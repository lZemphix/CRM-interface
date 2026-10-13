import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/employee_forms.dart';
import 'dialog_frame.dart';

class CreateEmployeeDialog extends StatefulWidget {
  const CreateEmployeeDialog({
    super.key,
    this.roles = const [],
    this.branches = const [],
    this.onCreate,
  });

  final List<EmployeeRoleChoice> roles;
  final List<EmployeeBranchChoice> branches;
  final Future<EmployeeCreatedView> Function(EmployeeCreateDraft)? onCreate;

  @override
  State<CreateEmployeeDialog> createState() => _CreateEmployeeDialogState();
}

class _CreateEmployeeDialogState extends State<CreateEmployeeDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _branches = <int>{};
  int? _role;
  int? _primary;
  bool _saving = false;
  bool _blocked = false;
  bool _showPassword = false;
  String? _error;
  String? _copyStatus;
  EmployeeCreatedView? _created;

  @override
  void dispose() {
    _created = null;
    _name.dispose();
    _login.dispose();
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final create = widget.onCreate;
    if (_saving ||
        _blocked ||
        create == null ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await create(
        EmployeeCreateDraft(
          fullName: _name.text.trim(),
          login: _login.text.trim().toLowerCase(),
          roleId: _role!,
          branchIds: _branches,
          primaryBranchId: _primary,
        ),
      );
      if (!mounted) return;
      setState(() {
        _created = result;
        _password.text = result.temporaryPassword;
      });
    } on EmployeeFormFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _blocked = !error.retryAllowed;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _roleField() {
    final selected = widget.roles.where((role) => role.id == _role).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        DropdownButtonFormField<int>(
          key: const Key('employee-role'),
          initialValue: _role,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Роль *'),
          hint: Text(
            widget.roles.isEmpty
                ? 'Справочник пока не подключён'
                : 'Выберите роль',
            overflow: TextOverflow.ellipsis,
          ),
          items: [
            for (final role in widget.roles)
              DropdownMenuItem(
                value: role.id,
                child: Text(role.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _saving || widget.roles.isEmpty
              ? null
              : (value) => setState(() => _role = value),
          validator: (value) => value == null ? 'Выберите роль' : null,
        ),
        if (selected != null && selected.description.isNotEmpty)
          EmployeeInfoBox(selected.description),
      ],
    );
  }

  Widget _branchFields() => Container(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.notActiveBorder),
      borderRadius: BorderRadius.circular(10),
    ),
    child: ExpansionTile(
      key: const Key('employee-branches'),
      shape: const Border(),
      collapsedShape: const Border(),
      title: const Text('Филиалы', style: TextStyle(fontSize: 12)),
      subtitle: Text(
        _branches.isEmpty ? 'Необязательно' : 'Выбрано: ${_branches.length}',
        style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      children: [
        if (widget.branches.isEmpty)
          const Text(
            'Филиалы появятся после подключения API.',
            style: TextStyle(fontSize: 12, color: AppColors.textMutted),
          ),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final branch in widget.branches)
              FilterChip(
                label: Text(branch.name, style: const TextStyle(fontSize: 12)),
                selected: _branches.contains(branch.id),
                onSelected: _saving
                    ? null
                    : (selected) => setState(() {
                        selected
                            ? _branches.add(branch.id)
                            : _branches.remove(branch.id);
                        if (!_branches.contains(_primary)) _primary = null;
                      }),
              ),
          ],
        ),
        if (_branches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<int>(
              key: ValueKey('employee-primary-${_branches.join('-')}'),
              initialValue: _primary,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Основной филиал'),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('Без предпочтения'),
                ),
                for (final branch in widget.branches)
                  if (_branches.contains(branch.id))
                    DropdownMenuItem(
                      value: branch.id,
                      child: Text(branch.name, overflow: TextOverflow.ellipsis),
                    ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _primary = value),
            ),
          ),
      ],
    ),
  );

  Widget _fields() => Form(
    key: _form,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        TextFormField(
          key: const Key('employee-name'),
          controller: _name,
          enabled: !_saving,
          autofocus: true,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: 'ФИО *',
            hintText: 'Имя и фамилия',
            counterText: '',
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Укажите ФИО' : null,
        ),
        TextFormField(
          key: const Key('employee-login'),
          controller: _login,
          enabled: !_saving,
          maxLength: 128,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Логин *',
            helperText: 'От 3 символов: латиница, цифры, точка, дефис, _',
            helperMaxLines: 2,
            counterText: '',
          ),
          validator: validateEmployeeLogin,
        ),
        _roleField(),
        _branchFields(),
        const EmployeeInfoBox(
          'Временный пароль выдаст сервер после создания. При первом входе сотрудник должен будет его сменить.',
        ),
        if (_error != null) EmployeeFormError(_error!),
      ],
    ),
  );

  Future<void> _copy() async {
    final created = _created;
    if (created == null) return;
    try {
      await Clipboard.setData(
        ClipboardData(
          text: 'Логин: ${created.login}\nВременный пароль: ${_password.text}',
        ),
      );
      if (mounted) {
        setState(
          () => _copyStatus =
              'Данные скопированы. Передайте их безопасным способом.',
        );
      }
    } on PlatformException {
      if (mounted) {
        setState(
          () => _copyStatus =
              'Копирование недоступно. Покажите пароль и скопируйте вручную.',
        );
      }
    }
  }

  Widget _result(EmployeeCreatedView created) => EmployeeDialogFrame(
    title: 'Сотрудник создан',
    description: created.fullName,
    icon: Icons.check,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        const Text(
          'Логин',
          style: TextStyle(fontSize: 12, color: AppColors.textMutted),
        ),
        SelectableText(created.login),
        TextField(
          key: const Key('employee-temporary-password'),
          controller: _password,
          readOnly: true,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: 'Временный пароль',
            suffixIcon: IconButton(
              tooltip: _showPassword ? 'Скрыть пароль' : 'Показать пароль',
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const EmployeeInfoBox(
          'Передайте данные сотруднику лично. После закрытия пароль больше не показывается и не сохраняется в приложении.',
          warning: true,
        ),
        if (_copyStatus != null)
          Text(_copyStatus!, style: const TextStyle(fontSize: 12)),
      ],
    ),
    actions: [
      OutlinedButton(onPressed: _copy, child: const Text('Скопировать данные')),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Готово'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final created = _created;
    if (created != null) return _result(created);
    return EmployeeDialogFrame(
      title: 'Новый сотрудник',
      description: 'Создайте аккаунт и задайте уровень доступа.',
      icon: Icons.person_add_alt_outlined,
      busy: _saving,
      body: _fields(),
      note: widget.onCreate == null
          ? 'Предпросмотр формы. API не подключён: реальные сотрудники не создаются, роли и филиалы не загружаются.'
          : null,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('employee-create-submit'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.activeElement,
          ),
          onPressed:
              widget.onCreate == null ||
                  _saving ||
                  _blocked ||
                  widget.roles.isEmpty
              ? null
              : _submit,
          child: Text(_saving ? 'Создаём…' : 'Создать сотрудника'),
        ),
      ],
    );
  }
}
