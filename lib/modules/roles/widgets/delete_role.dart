import 'package:flutter/material.dart';
import 'package:crm_interface/core/keyboard/dialog_keyboard_scope.dart';

import '../models/role.dart';
import '../repos/roles_repository.dart';
import 'dialog_frame.dart';

class DeleteRoleDialog extends StatefulWidget {
  const DeleteRoleDialog({super.key, required this.repository});
  final RolesRepository repository;
  @override
  State<DeleteRoleDialog> createState() => _DeleteRoleDialogState();
}

class _DeleteRoleDialogState extends State<DeleteRoleDialog> {
  final _keyboard = GlobalKey<DialogKeyboardScopeState>();
  late Future<List<RoleInfo>> _roles;
  int? _selected;
  RoleInfo? _confirmed;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _roles = widget.repository.getRoles();
  }

  void _reload() {
    final roles = widget.repository.getRoles();
    setState(() {
      _roles = roles;
      _selected = null;
      _confirmed = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || _selected == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final role = _confirmed;
      if (role == null) {
        final current = await widget.repository.getRole(_selected!);
        if (mounted) setState(() => _confirmed = current);
      } else if (role.canDelete) {
        await widget.repository.delete(role.id);
        if (mounted) Navigator.of(context).pop(true);
      }
    } on RoleRequestFailure catch (error) {
      if (mounted) {
        if (error.refreshRequired) _reload();
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _fields(List<RoleInfo> roles) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 14,
    children: [
      if (roles.isEmpty) const RoleMessage('Ролей пока нет. Удалять нечего.'),
      if (roles.isNotEmpty)
        DropdownButtonFormField<int>(
          // Recreate only the selector when a fresh list invalidates confirmation.
          key: ValueKey(_roles),
          initialValue: _selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Роль для удаления'),
          items: [
            for (final role in roles)
              DropdownMenuItem(
                value: role.id,
                child: Text(
                  '${role.name} (${role.code})${role.isSystem ? ' · системная' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _selected = value;
                  _confirmed = null;
                  _error = null;
                }),
        ),
      if (_confirmed case final role?) ...[
        RoleMessage(
          '${role.name}\nКод: ${role.code}\nНазначена сотрудникам: ${role.employeeCount}\nРазрешений: ${role.permissions.length}',
        ),
        RoleMessage(
          role.isSystem
              ? 'Системную роль удалить нельзя.'
              : role.employeeCount > 0
              ? 'Роль используется. Сначала назначьте другую роль всем сотрудникам, включая архивированных.'
              : 'Роль будет удалена без возможности восстановления. Подтвердите удаление.',
          error: !role.canDelete,
        ),
      ] else
        const RoleMessage(
          'Сначала проверим актуальную роль. Удаление возможно только для несистемной роли без сотрудников.',
        ),
      if (_error != null) RoleMessage(_error!, error: true),
    ],
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<RoleInfo>>(
    future: _roles,
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
        hasChanges: () => _selected != null,
        title: 'Удалить роль',
        description: 'Без удаления сотрудников и их истории.',
        danger: true,
        busy: _busy,
        body: ready
            ? _fields(snapshot.data!)
            : error != null
            ? RoleMessage(
                error is RoleRequestFailure
                    ? error.message
                    : 'Не удалось загрузить роли.',
                error: true,
              )
            : const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => _keyboard.currentState?.requestClose(),
            child: const Text('Отмена'),
          ),
          if (error != null)
            FilledButton(onPressed: _reload, child: const Text('Повторить')),
          if (ready)
            FilledButton(
              key: const Key('role-delete-submit'),
              style: _confirmed == null
                  ? null
                  : FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB42318),
                    ),
              onPressed:
                  _busy || _selected == null || _confirmed?.canDelete == false
                  ? null
                  : _submit,
              child: Text(
                _busy
                    ? 'Подождите…'
                    : _confirmed == null
                    ? 'Продолжить'
                    : 'Удалить роль',
              ),
            ),
        ],
      );
    },
  );
}
