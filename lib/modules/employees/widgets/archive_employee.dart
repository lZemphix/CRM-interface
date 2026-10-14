import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:flutter/material.dart';

import '../models/employee_forms.dart';
import 'dialog_frame.dart';

class ArchiveEmployeeDialog extends StatefulWidget {
  const ArchiveEmployeeDialog({super.key, this.onLookup, this.onArchive});

  final Future<EmployeeArchiveView> Function(String login)? onLookup;
  final Future<void> Function(EmployeeArchiveView employee)? onArchive;

  @override
  State<ArchiveEmployeeDialog> createState() => _ArchiveEmployeeDialogState();
}

class _ArchiveEmployeeDialogState extends State<ArchiveEmployeeDialog> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  EmployeeArchiveView? _employee;
  bool _busy = false;
  bool _blocked = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _blocked || !_form.currentState!.validate()) return;
    final employee = _employee;
    if (employee == null && widget.onLookup == null ||
        employee != null && widget.onArchive == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (employee == null) {
        final result = await widget.onLookup!(_login.text.trim().toLowerCase());
        if (result.login.trim().toLowerCase() !=
            _login.text.trim().toLowerCase()) {
          throw const EmployeeFormFailure(
            'Получены данные другого логина. Проверьте сотрудника заново.',
          );
        }
        if (mounted) setState(() => _employee = result);
      } else {
        await widget.onArchive!(employee);
        if (mounted) Navigator.of(context).pop(true);
      }
    } on EmployeeFormFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _blocked = !error.retryAllowed;
          if (error.refreshRequired) _employee = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _identity(EmployeeArchiveView employee) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 14,
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.notActiveBorder),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(
              employee.fullName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              '${employee.login} · ${employee.roleName}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMutted),
            ),
          ],
        ),
      ),
      if (employee.isActive)
        const Text(
          'Доступ к CRM прекратится, активные сессии завершатся. История действий и завершённые задачи сохранятся.',
          style: TextStyle(
            fontSize: 12,
            height: 1.6,
            color: AppColors.textMutted,
          ),
        ),
      EmployeeInfoBox(
        !employee.isActive
            ? 'Сотрудник уже архивирован. Повторное отключение не требуется.'
            : employee.openTasks == 0
            ? 'Открытых задач нет. Меняется только доступ сотрудника.'
            : 'Открытых задач: ${employee.openTasks}. Они останутся без ответственного. Статусы и колонки не изменятся.',
        warning: true,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final employee = _employee;
    final connected = employee == null
        ? widget.onLookup != null
        : widget.onArchive != null;
    return EmployeeDialogFrame(
      title: 'Архивировать сотрудника',
      description: 'Отключение доступа, а не удаление истории.',
      icon: Icons.inventory_2_outlined,
      danger: true,
      busy: _busy,
      note: widget.onLookup == null
          ? 'Предпросмотр формы. API не подключён: проверка логина и архивирование пока недоступны.'
          : null,
      body: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            TextFormField(
              key: const Key('employee-archive-login'),
              controller: _login,
              enabled: !_busy,
              autofocus: true,
              maxLength: 128,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Введите логин сотрудника *',
                helperText: 'Точный логин, без поиска и подсказок.',
                helperMaxLines: 2,
                counterText: '',
              ),
              validator: validateEmployeeLogin,
              onChanged: (_) => setState(() {
                _employee = null;
                if (!_blocked) _error = null;
              }),
            ),
            if (employee != null) _identity(employee),
            if (_error != null) EmployeeFormError(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('employee-archive-submit'),
          style: FilledButton.styleFrom(
            backgroundColor: employee == null
                ? AppColors.activeElement
                : const Color(0xFFB42318),
          ),
          onPressed:
              !connected || _busy || _blocked || employee?.isActive == false
              ? null
              : _submit,
          child: Text(
            _busy
                ? 'Подождите…'
                : employee == null
                ? 'Продолжить'
                : 'Архивировать',
          ),
        ),
      ],
    );
  }
}
