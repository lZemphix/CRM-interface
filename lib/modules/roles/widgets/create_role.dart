import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:flutter/material.dart';
import 'package:crm_interface/core/keyboard/dialog_keyboard_scope.dart';

import '../models/role.dart';
import '../repos/roles_repository.dart';
import 'dialog_frame.dart';

class CreateRoleDialog extends StatefulWidget {
  const CreateRoleDialog({super.key, required this.repository});
  final RolesRepository repository;
  @override
  State<CreateRoleDialog> createState() => _CreateRoleDialogState();
}

class _CreateRoleDialogState extends State<CreateRoleDialog> {
  final _form = GlobalKey<FormState>();
  final _keyboard = GlobalKey<DialogKeyboardScopeState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _description = TextEditingController();
  final _selected = <String>{};
  late Future<List<RolePermission>> _permissions;
  bool _saving = false;
  bool _blocked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _permissions = widget.repository.getPermissions();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || _blocked || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final role = await widget.repository.create(
        CreateRoleRequest(
          code: _code.text,
          name: _name.text,
          description: _description.text,
          permissions: _selected,
        ),
      );
      if (mounted) Navigator.of(context).pop(role);
    } on RoleRequestFailure catch (error) {
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

  Widget _fields(List<RolePermission> permissions) => Form(
    key: _form,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        TextFormField(
          key: const Key('role-name'),
          controller: _name,
          enabled: !_saving,
          autofocus: true,
          maxLength: 128,
          decoration: const InputDecoration(
            labelText: 'Название *',
            counterText: '',
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Укажите название' : null,
        ),
        TextFormField(
          key: const Key('role-code'),
          controller: _code,
          enabled: !_saving,
          maxLength: 64,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Код *',
            hintText: 'Например, operator',
            helperText: '2–64 символа: латиница, цифры, _ и -. Код уникален.',
            helperMaxLines: 2,
            counterText: '',
          ),
          validator: (value) =>
              RegExp(r'^[a-z0-9][a-z0-9_-]{1,63}$')
                  .hasMatch(value?.trim().toLowerCase() ?? '')
              ? null
              : 'Укажите корректный код роли',
        ),
        TextFormField(
          key: const Key('role-description'),
          controller: _description,
          enabled: !_saving,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Описание',
            counterText: '',
          ),
        ),
        const Text(
          'Разрешения',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const RoleMessage(
          'Выберите только необходимые права. Сервер не позволит выдать права, которых нет у вас.',
        ),
        if (permissions.isEmpty)
          const RoleMessage(
            'Справочник разрешений пуст. Роль можно создать без прав.',
          ),
        for (final permission in permissions)
          CheckboxListTile(
            key: ValueKey('role-permission-${permission.code}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.activeElement,
            dense: true,
            title: Text(permission.name, style: const TextStyle(fontSize: 12)),
            subtitle: Text(
              [
                permission.code,
                if (permission.description?.isNotEmpty == true)
                  permission.description!,
              ].join('\n'),
              style: const TextStyle(fontSize: 11, color: AppColors.textMutted),
            ),
            value: _selected.contains(permission.code),
            onChanged: _saving
                ? null
                : (checked) => setState(() {
                    checked == true
                        ? _selected.add(permission.code)
                        : _selected.remove(permission.code);
                  }),
          ),
        if (_selected.isEmpty)
          const RoleMessage(
            'Права не выбраны. У сотрудника с этой ролью не будет доступа к бизнес-функциям.',
          ),
        if (_error != null) RoleMessage(_error!, error: true),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<RolePermission>>(
    future: _permissions,
    builder: (context, snapshot) {
      final ready =
          snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          snapshot.hasData;
      final error = snapshot.connectionState == ConnectionState.done
          ? snapshot.error
          : null;
      return RoleDialogFrame(
        keyboardKey: _keyboard,
        hasChanges: () =>
            _name.text.isNotEmpty ||
            _code.text.isNotEmpty ||
            _description.text.isNotEmpty ||
            _selected.isNotEmpty,
        onSubmit: ready ? _submit : null,
        title: 'Новая роль',
        description: 'Название и набор прав для сотрудников.',
        busy: _saving,
        body: ready
            ? _fields(snapshot.data!)
            : error != null
            ? RoleMessage(
                error is RoleRequestFailure
                    ? error.message
                    : 'Не удалось загрузить разрешения.',
                error: true,
              )
            : const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () => _keyboard.currentState?.requestClose(),
            child: const Text('Отмена'),
          ),
          if (error != null)
            FilledButton(
              onPressed: () {
                final permissions = widget.repository.getPermissions();
                setState(() {
                  _permissions = permissions;
                });
              },
              child: const Text('Повторить'),
            ),
          if (ready)
            FilledButton(
              key: const Key('role-create-submit'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.activeElement,
              ),
              onPressed: _saving || _blocked ? null : _submit,
              child: Text(_saving ? 'Создаём…' : 'Создать роль'),
            ),
        ],
      );
    },
  );
}
