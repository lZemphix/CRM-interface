import 'package:flutter/material.dart';

import '../models/taskboard.dart';
import '../models/tasks.dart';
import '../repos/request_error.dart';
import 'task_card.dart';
import 'customer_field.dart';

class TaskActionWindow extends StatefulWidget {
  const TaskActionWindow({
    super.key,
    required this.task,
    required this.action,
    required this.employees,
    required this.onEdit,
    required this.onAssign,
    this.searchCustomers,
  });

  final TaskboardTask task;
  final TaskCardAction action;
  final List<TaskEmployee> employees;
  final Future<void> Function(EditTaskRequest) onEdit;
  final Future<void> Function(AssignTaskRequest) onAssign;
  final Future<List<TaskCustomerOption>> Function(String)? searchCustomers;

  @override
  State<TaskActionWindow> createState() => _TaskActionWindowState();
}

class _TaskActionWindowState extends State<TaskActionWindow> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _description;
  Priority? _priority;
  late int _employeeId;
  String _reason = '';
  bool _saving = false;
  String? _error;
  TaskCustomerOption? _customer;
  bool _customerChanged = false;

  bool get _isEdit => widget.action == TaskCardAction.edit;

  @override
  void initState() {
    super.initState();
    _title = widget.task.title;
    if (widget.task.customerId != null) {
      _customer = TaskCustomerOption(
        id: widget.task.customerId!,
        fullName:
            widget.task.customerName ?? 'Клиент #${widget.task.customerId}',
      );
    }
    _description = widget.task.description ?? '';
    _priority = Priority.values
        .where((item) => item.name == widget.task.priority)
        .firstOrNull;
    _employeeId = widget.task.responsibleEmployeeId ?? 0;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await widget.onEdit(
          EditTaskRequest(
            title: _title,
            description: _description,
            priority: _priority!,
            version: widget.task.version,
            customerId: _customer?.id,
            updateCustomer: _customerChanged,
          ),
        );
      } else {
        await widget.onAssign(
          AssignTaskRequest(
            employeeId: _employeeId == 0 ? null : _employeeId,
            reason: _reason.isEmpty ? null : _reason,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on TaskRequestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось сохранить изменения. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          _isEdit ? 'Редактировать задачу' : 'Назначить ответственного',
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...(_isEdit ? _editFields() : _assignmentFields()),
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
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Сохраняем…' : 'Сохранить'),
          ),
        ],
      ),
    );
  }

  List<Widget> _editFields() => [
    if (widget.searchCustomers != null) ...[
      TaskCustomerField(
        initialCustomer: _customer,
        searchCustomers: widget.searchCustomers,
        enabled: !_saving,
        onSelected: (customer) {
          _customer = customer;
          _customerChanged = customer?.id != widget.task.customerId;
        },
      ),
      const SizedBox(height: 12),
    ],
    TextFormField(
      initialValue: _title,
      enabled: !_saving,
      maxLength: 255,
      decoration: const InputDecoration(labelText: 'Название *'),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Введите название' : null,
      onSaved: (value) => _title = value!.trim(),
    ),
    TextFormField(
      initialValue: _description,
      enabled: !_saving,
      maxLength: 4000,
      minLines: 3,
      maxLines: 6,
      decoration: const InputDecoration(labelText: 'Описание'),
      onSaved: (value) => _description = value?.trim() ?? '',
    ),
    DropdownButtonFormField<Priority>(
      initialValue: _priority,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Важность *'),
      validator: (value) => value == null ? 'Выберите важность' : null,
      items: [
        for (final priority in Priority.values)
          DropdownMenuItem(
            value: priority,
            child: Text(switch (priority) {
              Priority.low => 'Низкая',
              Priority.normal => 'Обычная',
              Priority.high => 'Высокая',
              Priority.urgent => 'Срочная',
            }),
          ),
      ],
      onChanged: _saving ? null : (value) => _priority = value,
    ),
  ];

  List<Widget> _assignmentFields() {
    final employees = [...widget.employees];
    final current = widget.task.responsibleEmployeeId;
    if (current != null &&
        !employees.any((employee) => employee.id == current)) {
      employees.add(
        TaskEmployee(
          id: current,
          fullName:
              widget.task.responsibleEmployeeName ?? 'Сотрудник #$current',
        ),
      );
    }
    return [
      DropdownButtonFormField<int>(
        initialValue: _employeeId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Ответственный'),
        items: [
          const DropdownMenuItem(value: 0, child: Text('Без ответственного')),
          for (final employee in employees)
            DropdownMenuItem(
              value: employee.id,
              child: Text(employee.fullName, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _saving
            ? null
            : (value) {
                if (value != null) _employeeId = value;
              },
      ),
      const SizedBox(height: 12),
      TextFormField(
        enabled: !_saving,
        maxLength: 2000,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Причина переназначения (необязательно)',
        ),
        onSaved: (value) => _reason = value?.trim() ?? '',
      ),
    ];
  }
}
