import 'package:crm_interface/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:crm_interface/core/keyboard/dialog_keyboard_scope.dart';
import 'package:flutter/services.dart';

import '../models/employee_forms.dart';
import 'dialog_frame.dart';

class CreateEmployeeDialog extends StatefulWidget {
  const CreateEmployeeDialog({
    super.key,
    this.roles = const [],
    this.branches = const [],
    this.onCreate,
    this.onCreateRole,
  });

  final List<EmployeeRoleChoice> roles;
  final List<EmployeeBranchChoice> branches;
  final Future<EmployeeCreatedView> Function(EmployeeCreateDraft)? onCreate;
  final Future<EmployeeRoleChoice?> Function()? onCreateRole;

  @override
  State<CreateEmployeeDialog> createState() => _CreateEmployeeDialogState();
}

class _CreateEmployeeDialogState extends State<CreateEmployeeDialog> {
  final _form = GlobalKey<FormState>();
  final _keyboard = GlobalKey<DialogKeyboardScopeState>();
  bool _dirty = false;
  final _roleFieldState = GlobalKey<FormFieldState<int>>();
  late final List<EmployeeRoleChoice> _roles = [...widget.roles];
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _branches = <int>{};
  int? _role;
  int? _primary;
  bool _saving = false;
  bool _creatingRole = false;
  bool get _busy => _saving || _creatingRole;
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
    if (_busy ||
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

  Future<void> _createRole() async {
    if (_busy || widget.onCreateRole == null) return;
    setState(() {
      _creatingRole = true;
      _error = null;
    });
    try {
      final role = await widget.onCreateRole!();
      if (!mounted) return;
      if (role != null) {
        setState(() {
          _roles.removeWhere((existing) => existing.id == role.id);
          _roles.add(role);
          _role = role.id;
        });
      }
    } on EmployeeFormFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) {
        // The last dropdown item is an action, never a role_id.
        _roleFieldState.currentState?.didChange(_role);
        setState(() => _creatingRole = false);
      }
    }
  }

  Widget _roleField() {
    final selected = _roles.where((role) => role.id == _role).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        SizedBox(
          key: const Key('employee-role'),
          child: DropdownButtonFormField<int>(
            key: _roleFieldState,
            initialValue: _role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Роль *'),
            hint: Text(
              _roles.isEmpty
                  ? widget.onCreate == null
                        ? 'Справочник пока не подключён'
                        : 'Доступных ролей нет'
                  : 'Выберите роль',
              overflow: TextOverflow.ellipsis,
            ),
            items: [
              for (final role in _roles)
                DropdownMenuItem(
                  value: role.id,
                  child: Text(role.name, overflow: TextOverflow.ellipsis),
                ),
              if (widget.onCreateRole != null)
                DropdownMenuItem(
                  value: -1,
                  child: Row(
                    spacing: 8,
                    children: [
                      Icon(Icons.add, size: 18, color: context.colors.accent),
                      Text(
                        'Создать роль…',
                        style: TextStyle(color: context.colors.accent),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: _busy || (_roles.isEmpty && widget.onCreateRole == null)
                ? null
                : (value) {
                    if (value == -1) {
                      _createRole();
                    } else {
                      setState(() => _role = value);
                    }
                  },
            validator: (value) =>
                value == null || value < 1 ? 'Выберите роль' : null,
          ),
        ),
        if (selected != null && selected.description.isNotEmpty)
          EmployeeInfoBox(selected.description),
      ],
    );
  }

  Widget _branchFields() => Container(
    decoration: BoxDecoration(
      border: Border.all(color: context.colors.notActiveBorder),
      borderRadius: BorderRadius.circular(10),
    ),
    child: ExpansionTile(
      key: const Key('employee-branches'),
      shape: const Border(),
      collapsedShape: const Border(),
      title: const Text('Филиалы', style: TextStyle(fontSize: 12)),
      subtitle: Text(
        _branches.isEmpty ? 'Необязательно' : 'Выбрано: ${_branches.length}',
        style: TextStyle(fontSize: 11, color: context.colors.textFaint),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      children: [
        if (widget.branches.isEmpty)
          Text(
            widget.onCreate == null
                ? 'Филиалы появятся после подключения API.'
                : 'Активных филиалов нет. Сотрудника можно создать без филиала.',
            style: TextStyle(fontSize: 12, color: context.colors.textMutted),
          ),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final branch in widget.branches)
              FilterChip(
                label: Text(branch.name, style: const TextStyle(fontSize: 12)),
                selected: _branches.contains(branch.id),
                onSelected: _busy
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
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _primary = value),
            ),
          ),
      ],
    ),
  );

  Widget _fields() => Form(
    key: _form,
    onChanged: () => _dirty = true,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        TextFormField(
          key: const Key('employee-name'),
          controller: _name,
          enabled: !_busy,
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
          enabled: !_busy,
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
        if (_roles.isEmpty && widget.onCreate != null)
          const EmployeeInfoBox(
            'Для создания сотрудника нужна роль. Обратитесь к администратору, чтобы добавить доступные роли.',
            warning: true,
          ),
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
        Text(
          'Логин',
          style: TextStyle(fontSize: 12, color: context.colors.textMutted),
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
      keyboardKey: _keyboard,
      hasChanges: () => _dirty || _branches.isNotEmpty || _role != null,
      onSubmit: _roles.isEmpty ? null : _submit,
      title: 'Новый сотрудник',
      description: 'Создайте аккаунт и задайте уровень доступа.',
      icon: Icons.person_add_alt_outlined,
      busy: _busy,
      body: _fields(),
      note: widget.onCreate == null
          ? 'Предпросмотр формы. API не подключён: реальные сотрудники не создаются, роли и филиалы не загружаются.'
          : null,
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => _keyboard.currentState?.requestClose(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('employee-create-submit'),
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.activeElement,
          ),
          onPressed:
              widget.onCreate == null || _busy || _blocked || _roles.isEmpty
              ? null
              : _submit,
          child: Text(_saving ? 'Создаём…' : 'Создать сотрудника'),
        ),
      ],
    );
  }
}
