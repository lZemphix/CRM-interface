import 'package:flutter/material.dart';
import 'package:crm_interface/core/keyboard/dialog_keyboard_scope.dart';

import '../models/taskboard.dart';
import '../models/tasks.dart';
import '../repos/request_error.dart';
import 'task_card.dart';
import 'customer_field.dart';
import 'task_checklist_editor.dart';

class TaskActionWindow extends StatefulWidget {
  const TaskActionWindow({
    super.key,
    required this.task,
    required this.action,
    required this.employees,
    required this.onEdit,
    required this.onAssign,
    this.searchCustomers,
    this.includeAssignment = false,
    this.assignmentEnabled = true,
    this.onReload,
  });

  final TaskboardTask task;
  final TaskCardAction action;
  final List<TaskEmployee> employees;
  final Future<TaskboardTask> Function(EditTaskRequest) onEdit;
  final Future<TaskboardTask> Function(AssignTaskRequest) onAssign;
  final Future<List<TaskCustomerOption>> Function(String)? searchCustomers;
  final bool includeAssignment;
  final bool assignmentEnabled;
  final Future<TaskboardTask> Function()? onReload;

  @override
  State<TaskActionWindow> createState() => _TaskActionWindowState();
}

class _TaskActionWindowState extends State<TaskActionWindow> {
  final _formKey = GlobalKey<FormState>();
  final _keyboard = GlobalKey<DialogKeyboardScopeState>();
  bool _dirty = false;
  late String _title;
  late String _description;
  Priority? _priority;
  late int _employeeId;
  String _reason = '';
  bool _saving = false;
  String? _error;
  TaskCustomerOption? _customer;
  bool _customerChanged = false;
  late TaskboardTask _baseline;
  bool _requiresRefresh = false;
  int _formRevision = 0;
  late List<TaskSubtaskDraft> _subtasks;
  bool _checklistConflict = false;

  bool get _isEdit => widget.action == TaskCardAction.edit;
  bool get _combined => _isEdit && widget.includeAssignment;
  bool get _closed =>
      _combined && const {'confirmed', 'cancelled'}.contains(_baseline.status);
  bool get _fieldsEnabled => !_saving && !_requiresRefresh && !_closed;
  bool get _canAssignStatus =>
      const {'new', 'in_progress', 'rework'}.contains(_baseline.status);
  bool get _checklistChanged => !_sameChecklist(_subtasks, _drafts(_baseline));

  List<TaskSubtaskDraft> _drafts(TaskboardTask task) => [
    for (final item in task.subtasks)
      TaskSubtaskDraft(id: item.id, title: item.title),
  ];

  bool _sameChecklist(List<TaskSubtaskDraft> a, List<TaskSubtaskDraft> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].title != b[i].title) return false;
    }
    return true;
  }

  bool _matchesSubmittedChecklist(TaskboardTask fresh, TaskboardTask previous) {
    if (_subtasks.length != fresh.subtasks.length) return false;
    final previousIds = previous.subtasks.map((item) => item.id).toSet();
    for (var i = 0; i < _subtasks.length; i++) {
      final desired = _subtasks[i];
      final actual = fresh.subtasks[i];
      if (desired.title != actual.title) return false;
      if (desired.id != null
          ? desired.id != actual.id
          : previousIds.contains(actual.id)) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _baseline = widget.task;
    _subtasks = _drafts(widget.task);
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
    if (!_fieldsEnabled ||
        _checklistConflict ||
        !_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();
    var parametersSaved = false;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        final parametersChanged =
            !_combined ||
            _title != _baseline.title ||
            _description != (_baseline.description ?? '') ||
            _priority?.name != _baseline.priority ||
            _customerChanged ||
            _checklistChanged;
        if (parametersChanged) {
          final updated = await widget.onEdit(
            EditTaskRequest(
              title: _title,
              description: _description,
              priority: _priority!,
              version: _baseline.version,
              customerId: _customer?.id,
              updateCustomer: _customerChanged,
              subtasks: _checklistChanged ? List.of(_subtasks) : null,
            ),
          );
          parametersSaved = true;
          _baseline = updated;
          if (_combined) {
            _adoptMetadata(updated);
            _formRevision++;
          }
        }
        if (_combined &&
            _employeeId != (_baseline.responsibleEmployeeId ?? 0)) {
          if (!_canAssignStatus || !widget.assignmentEnabled) {
            throw const TaskRequestException(
              'В этом состоянии задачи исполнитель не может быть изменён.',
            );
          }
          _baseline = await widget.onAssign(_assignmentRequest());
        }
      } else {
        await widget.onAssign(_assignmentRequest());
      }
      if (mounted) Navigator.of(context).pop();
    } on TaskRequestException catch (error) {
      _saveFailed(error.message, parametersSaved);
    } catch (_) {
      _saveFailed(
        'Не удалось подтвердить сохранение изменений.',
        parametersSaved,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  AssignTaskRequest _assignmentRequest() => AssignTaskRequest(
    employeeId: _employeeId == 0 ? null : _employeeId,
    reason: _reason.isEmpty ? null : _reason,
  );

  void _adoptMetadata(TaskboardTask task) {
    _title = task.title;
    _description = task.description ?? '';
    _priority = Priority.values
        .where((value) => value.name == task.priority)
        .firstOrNull;
    _customer = task.customerId == null
        ? null
        : TaskCustomerOption(
            id: task.customerId!,
            fullName: task.customerName ?? 'Клиент #${task.customerId}',
          );
    _customerChanged = false;
    _subtasks = _drafts(task);
  }

  void _saveFailed(String message, bool parametersSaved) {
    if (!mounted) return;
    setState(() {
      _requiresRefresh = _combined || _checklistChanged;
      _error =
          '${parametersSaved && _combined ? 'Параметры уже сохранены. Назначение не подтверждено. ' : ''}$message'
          '${_requiresRefresh ? ' Обновите состояние задачи перед повторным сохранением — введённые данные останутся в форме.' : ''}';
    });
  }

  Future<void> _reload() async {
    if (_saving || widget.onReload == null) return;
    _formKey.currentState!.save();
    final titleChanged = _title != _baseline.title;
    final descriptionChanged = _description != (_baseline.description ?? '');
    final priorityChanged = _priority?.name != _baseline.priority;
    final customerChanged = _customer?.id != _baseline.customerId;
    final assigneeChanged =
        _employeeId != (_baseline.responsibleEmployeeId ?? 0);
    final previous = _baseline;
    final checklistChanged = _checklistChanged;
    setState(() => _saving = true);
    try {
      final fresh = await widget.onReload!();
      if (!mounted) return;
      if (fresh.id != _baseline.id || fresh.version < _baseline.version) {
        throw const TaskRequestException(
          'Получены устаревшие данные задачи. Повторите обновление.',
        );
      }
      setState(() {
        if (!checklistChanged || _matchesSubmittedChecklist(fresh, previous)) {
          _subtasks = _drafts(fresh);
          _checklistConflict = false;
        } else if (!_sameChecklist(_drafts(previous), _drafts(fresh))) {
          _checklistConflict = true;
        }
        _baseline = fresh;
        if (!titleChanged) _title = fresh.title;
        if (!descriptionChanged) _description = fresh.description ?? '';
        if (!priorityChanged) {
          _priority = Priority.values
              .where((value) => value.name == fresh.priority)
              .firstOrNull;
        }
        if (!customerChanged) {
          _customer = fresh.customerId == null
              ? null
              : TaskCustomerOption(
                  id: fresh.customerId!,
                  fullName: fresh.customerName ?? 'Клиент #${fresh.customerId}',
                );
        }
        if (!assigneeChanged || !_canAssignStatus) {
          _employeeId = fresh.responsibleEmployeeId ?? 0;
        }
        _customerChanged = _customer?.id != fresh.customerId;
        _requiresRefresh = false;
        _error = _closed
            ? 'Задача закрыта. Изменение недоступно.'
            : assigneeChanged && !_canAssignStatus
            ? 'Статус задачи изменился: переназначение недоступно. Показан текущий исполнитель.'
            : null;
        if (_checklistConflict) {
          _error = 'Подзадачи изменились на сервере. Ваш черновик оставлен в форме. Загрузите актуальный список перед сохранением, чтобы не убрать чужие изменения.';
        }
        _formRevision++;
      });
    } on TaskRequestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось обновить задачу. Введённые данные сохранены в форме.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reloadChecklist() async {
    if (_saving) return;
    _formKey.currentState!.save();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DialogKeyboardScope(
        onClose: () => Navigator.of(context).pop(false),
        child: AlertDialog(
          title: const Text('Загрузить актуальные подзадачи?'),
          content: const Text(
            'Черновик списка будет заменён данными сервера. Остальные изменения формы сохранятся.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Оставить черновик'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Загрузить список'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _subtasks = _drafts(_baseline);
      _checklistConflict = false;
      _error = null;
      _formRevision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DialogKeyboardScope(
      key: _keyboard,
      busy: _saving,
      onSubmit: _save,
      hasChanges: () => _dirty || _customerChanged || _reason.isNotEmpty,
      child: AlertDialog(
        title: Text(
          _combined
              ? 'Изменить параметры задачи'
              : _isEdit
              ? 'Редактировать задачу'
              : 'Назначить ответственного',
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              onChanged: () => _dirty = true,
              child: Column(
                key: ValueKey(_formRevision),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...(_isEdit ? _editFields() : _assignmentFields()),
                  if (_combined) ...[
                    const SizedBox(height: 16),
                    ..._assignmentFields(),
                  ],
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
                  if (_requiresRefresh && widget.onReload != null)
                    TextButton(
                      onPressed: _saving ? null : _reload,
                      child: const Text('Обновить состояние задачи'),
                    ),
                  if (_checklistConflict)
                    TextButton(
                      onPressed: _saving ? null : _reloadChecklist,
                      child: const Text('Загрузить актуальные подзадачи'),
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
            onPressed: _fieldsEnabled && !_checklistConflict ? _save : null,
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
        enabled: _fieldsEnabled,
        onSelected: (customer) {
          _customer = customer;
          _customerChanged = customer?.id != _baseline.customerId;
        },
      ),
      const SizedBox(height: 12),
    ],
    TextFormField(
      initialValue: _title,
      enabled: _fieldsEnabled,
      maxLength: 255,
      decoration: const InputDecoration(labelText: 'Название *'),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Введите название' : null,
      onSaved: (value) => _title = value!.trim(),
    ),
    TextFormField(
      initialValue: _description,
      enabled: _fieldsEnabled,
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
      onChanged: !_fieldsEnabled ? null : (value) => _priority = value,
    ),
    const SizedBox(height: 16),
    TaskChecklistEditor(
      initialSubtasks: _subtasks,
      enabled: _fieldsEnabled,
      onChanged: (value) {
        _subtasks = value;
        _dirty = true;
      },
    ),
  ];

  List<Widget> _assignmentFields() {
    final employees = [...widget.employees];
    final current = _baseline.responsibleEmployeeId;
    if (current != null &&
        !employees.any((employee) => employee.id == current)) {
      employees.add(
        TaskEmployee(
          id: current,
          fullName: _baseline.responsibleEmployeeName ?? 'Сотрудник #$current',
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
        onChanged:
            !_fieldsEnabled ||
                (_combined && (!_canAssignStatus || !widget.assignmentEnabled))
            ? null
            : (value) {
                if (value != null) _employeeId = value;
              },
      ),
      if (_combined && (!_canAssignStatus || !widget.assignmentEnabled))
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            !_canAssignStatus ? 'В этом статусе нельзя менять исполнителя.' : 'Список сотрудников недоступен. Параметры задачи можно изменить; для назначения попробуйте открыть форму позже.',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      const SizedBox(height: 12),
      TextFormField(
        initialValue: _reason,
        enabled:
            _fieldsEnabled &&
            (!_combined || (_canAssignStatus && widget.assignmentEnabled)),
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
