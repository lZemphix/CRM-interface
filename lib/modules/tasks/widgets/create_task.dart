import 'dart:math' as math;

import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:flutter/material.dart';

import '../repos/request_error.dart';
import 'customer_field.dart';

class CreateTaskWindow extends StatefulWidget {
  const CreateTaskWindow({
    super.key,
    required this.columns,
    required this.employees,
    required this.onCreate,
    this.initialColumnId,
    this.searchCustomers,
    this.initialCustomer,
    this.lockCustomer = false,
  });

  final List<TaskboardColumn> columns;
  final List<TaskEmployee> employees;
  final Future<void> Function(CreateTaskRequest) onCreate;
  final int? initialColumnId;
  final Future<List<TaskCustomerOption>> Function(String)? searchCustomers;
  final TaskCustomerOption? initialCustomer;
  final bool lockCustomer;

  @override
  State<CreateTaskWindow> createState() => _CreateTaskWindowState();
}

class _SubtaskDraft {
  _SubtaskDraft(this.id);

  final int id;
  String title = '';
}

class _CreateTaskWindowState extends State<CreateTaskWindow> {
  final _formKey = GlobalKey<FormState>();
  final _subtasks = <_SubtaskDraft>[];
  int _nextSubtaskId = 0;
  String _title = '';
  String _description = '';
  String _reason = '';
  Priority _priority = Priority.normal;
  int? _responsibleEmployeeId;
  TaskCustomerOption? _customer;
  DateTime? _dueAt;
  late int _columnId;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _customer = widget.initialCustomer;
    _columnId =
        widget.initialColumnId ??
        int.parse(
          widget.columns.firstWhere((column) => column.canCreateTask).id,
        );
  }

  TaskboardColumn get _selectedColumn =>
      widget.columns.firstWhere((column) => int.parse(column.id) == _columnId);

  Future<void> _pickDueAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 20),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_dueAt!),
    );
    if (time == null || !mounted) return;

    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    if (_dueAt != null && !_dueAt!.isAfter(DateTime.now())) {
      setState(() => _saveError = 'Срок должен быть в будущем.');
      return;
    }

    final request = CreateTaskRequest(
      columnId: _columnId,
      title: _title,
      description: _description,
      priority: _priority,
      responsibleEmployeeId: _responsibleEmployeeId,
      dueAt: _dueAt,
      customerId: _customer?.id,
      reason: _selectedColumn.requiresReason ? _reason : null,
      subtasks: [
        for (final subtask in _subtasks) Subtask(title: subtask.title.trim()),
      ],
    );
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.onCreate(request);
      if (mounted) Navigator.of(context).pop();
    } on TaskRequestException catch (error) {
      if (mounted) setState(() => _saveError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError = 'Не удалось создать задачу. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = math.min(700.0, MediaQuery.sizeOf(context).height - 64);

    return Dialog(
      child: SizedBox(
        width: 620,
        height: height,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildForm()),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('Новая задача', style: TextStyle(fontSize: 22)),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitleField(),
            const SizedBox(height: 12),
            _buildDescriptionField(),
            const SizedBox(height: 16),
            _buildPriorityField(),
            if (widget.searchCustomers != null ||
                widget.initialCustomer != null) ...[
              const SizedBox(height: 16),
              TaskCustomerField(
                initialCustomer: widget.initialCustomer,
                searchCustomers: widget.searchCustomers,
                locked: widget.lockCustomer,
                enabled: !_isSaving,
                onSelected: (customer) => _customer = customer,
              ),
            ],
            const SizedBox(height: 16),
            _buildResponsibleField(),
            const SizedBox(height: 16),
            _buildColumnField(),
            if (_selectedColumn.requiresReason) ...[
              const SizedBox(height: 16),
              _buildReasonField(),
            ],
            const SizedBox(height: 16),
            _buildDeadlineField(),
            const SizedBox(height: 12),
            ..._buildSubtaskFields(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      autofocus: true,
      maxLength: 255,
      decoration: const InputDecoration(labelText: 'Название *'),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Введите название задачи'
          : null,
      onSaved: (value) => _title = value!.trim(),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      maxLines: 3,
      maxLength: 4000,
      decoration: const InputDecoration(labelText: 'Описание'),
      onSaved: (value) => _description = value?.trim() ?? '',
    );
  }

  Widget _buildPriorityField() {
    return DropdownButtonFormField<Priority>(
      initialValue: _priority,
      decoration: const InputDecoration(labelText: 'Важность'),
      items: const [
        DropdownMenuItem(value: Priority.low, child: Text('Низкая')),
        DropdownMenuItem(value: Priority.normal, child: Text('Обычная')),
        DropdownMenuItem(value: Priority.high, child: Text('Высокая')),
        DropdownMenuItem(value: Priority.urgent, child: Text('Срочная')),
      ],
      onChanged: (value) {
        if (value != null) _priority = value;
      },
    );
  }

  Widget _buildResponsibleField() {
    return DropdownButtonFormField<int?>(
      initialValue: _responsibleEmployeeId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Ответственный'),
      validator: (value) => _selectedColumn.requiresExecutor && value == null
          ? 'Для этой колонки выберите ответственного'
          : null,
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Без ответственного'),
        ),
        for (final employee in widget.employees)
          DropdownMenuItem<int?>(
            value: employee.id,
            child: Text(employee.fullName),
          ),
      ],
      onChanged: (value) => _responsibleEmployeeId = value,
    );
  }

  Widget _buildColumnField() {
    return DropdownButtonFormField<int>(
      initialValue: _columnId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Колонка'),
      items: [
        for (final column in widget.columns)
          DropdownMenuItem(
            value: int.parse(column.id),
            enabled: column.canCreateTask,
            child: Text(column.name),
          ),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _columnId = value);
      },
    );
  }

  Widget _buildReasonField() {
    return TextFormField(
      initialValue: _reason,
      maxLength: 1000,
      maxLines: 2,
      decoration: const InputDecoration(labelText: 'Причина доработки *'),
      onChanged: (value) => _reason = value,
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Укажите причину доработки'
          : null,
      onSaved: (value) => _reason = value!.trim(),
    );
  }

  Widget _buildDeadlineField() {
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            onPressed: _pickDueAt,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              _dueAt == null
                  ? 'Добавить срок'
                  : '${_dueAt!.day.toString().padLeft(2, '0')}.${_dueAt!.month.toString().padLeft(2, '0')}.${_dueAt!.year} '
                        '${_dueAt!.hour.toString().padLeft(2, '0')}:${_dueAt!.minute.toString().padLeft(2, '0')}',
            ),
          ),
        ),
        if (_dueAt != null)
          IconButton(
            tooltip: 'Убрать срок',
            onPressed: () => setState(() => _dueAt = null),
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }

  List<Widget> _buildSubtaskFields() {
    return [
      Text('Подзадачи', style: Theme.of(context).textTheme.titleMedium),
      for (final subtask in _subtasks)
        Row(
          key: ValueKey(subtask.id),
          children: [
            Expanded(
              child: TextFormField(
                initialValue: subtask.title,
                decoration: const InputDecoration(labelText: 'Подзадача'),
                maxLength: 255,
                onChanged: (value) => subtask.title = value,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите название или удалите подзадачу'
                    : null,
              ),
            ),
            IconButton(
              tooltip: 'Удалить подзадачу',
              onPressed: () => setState(() => _subtasks.remove(subtask)),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _subtasks.length >= 50
              ? null
              : () => setState(() {
                  _subtasks.add(_SubtaskDraft(_nextSubtaskId++));
                }),
          icon: const Icon(Icons.add),
          label: Text(
            _subtasks.length >= 50
                ? 'Лимит: 50 подзадач'
                : 'Добавить подзадачу',
          ),
        ),
      ),
    ];
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_saveError != null)
            Text(
              _saveError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: Text(_isSaving ? 'Создаём…' : 'Создать'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
