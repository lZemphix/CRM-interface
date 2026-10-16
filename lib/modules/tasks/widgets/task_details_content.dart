import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:crm_interface/core/theme/app_palette.dart';

import '../models/task_details.dart';
import '../models/taskboard.dart';

String _statusLabel(String? status) => switch (status) {
  'new' => 'Новая',
  'in_progress' => 'В работе',
  'completed' => 'На проверке',
  'rework' => 'Доработка',
  'confirmed' => 'Подтверждена',
  'cancelled' => 'Отменена',
  _ => 'Статус неизвестен',
};

class TaskDetailsHeader extends StatelessWidget {
  const TaskDetailsHeader({
    super.key,
    required this.task,
    required this.columnName,
    required this.onRefresh,
    required this.onHistory,
    required this.onClose,
  });

  final TaskboardTask task;
  final String? columnName;
  final VoidCallback? onRefresh;
  final VoidCallback? onHistory;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.colors.notActiveBorder)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'ЗАДАЧА #${task.id}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textMutted,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.accent.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      columnName ?? 'Колонка #${task.columnId}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 110),
                child: SingleChildScrollView(
                  child: SelectableText(
                    task.title,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: context.colors.taskCardText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Wrap(
          children: [
            IconButton(
              tooltip: 'Обновить карточку задачи',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 19),
            ),
            IconButton(
              tooltip: 'История задачи',
              onPressed: onHistory,
              icon: const Icon(Icons.history, size: 19),
            ),
            IconButton(
              tooltip: 'Закрыть карточку задачи',
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 19),
            ),
          ],
        ),
      ],
    ),
  );
}

class TaskDetailsSectionTitle extends StatelessWidget {
  const TaskDetailsSectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class TaskDetailsProperties extends StatelessWidget {
  const TaskDetailsProperties({
    super.key,
    required this.task,
    required this.details,
    required this.onEdit,
  });
  final TaskboardTask task;
  final TaskDetails details;
  final VoidCallback? onEdit;

  String get _priority => switch (task.priority) {
    'low' => 'Низкая',
    'normal' => 'Обычная',
    'high' => 'Высокая',
    'urgent' => 'Срочная',
    _ => task.priority,
  };

  String get _deadline {
    if (task.dueDate != null) {
      return '${DateFormat('dd.MM.yyyy').format(task.dueDate!)} · весь день';
    }
    if (task.dueAt != null) {
      return '${DateFormat('dd.MM.yyyy HH:mm').format(task.dueAt!.toLocal())} (местное время)';
    }
    return 'Не указан';
  }

  @override
  Widget build(BuildContext context) {
    final assignment = details.task.version == task.version
        ? details.currentAssignment
        : null;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: context.colors.notActiveBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TaskProperty('Статус', _statusLabel(task.status)),
          _TaskProperty(
            'Исполнитель',
            task.responsibleEmployeeName ??
                (task.responsibleEmployeeId == null
                    ? 'Не назначен'
                    : 'Сотрудник #${task.responsibleEmployeeId}'),
          ),
          _TaskProperty('Приоритет', _priority),
          _TaskProperty('Крайний срок', _deadline),
          if (task.customerId != null)
            _TaskProperty(
              'Клиент',
              task.customerName ?? 'Клиент #${task.customerId}',
            ),
          _TaskProperty(
            'Создал',
            details.author?.fullName ??
                (details.createdByEmployeeId == null
                    ? 'Нет данных'
                    : 'Сотрудник #${details.createdByEmployeeId}'),
          ),
          _TaskProperty(
            'Назначил',
            task.responsibleEmployeeId == null
                ? 'Не назначен'
                : assignment?.changedBy.fullName ?? 'Нет данных',
          ),
          if (assignment != null)
            _TaskProperty(
              'Назначение',
              DateFormat('dd.MM.yyyy HH:mm')
                  .format(assignment.changedAt.toLocal()),
            ),
          if (details.createdAt != null)
            _TaskProperty(
              'Создана',
              DateFormat('dd.MM.yyyy HH:mm')
                  .format(details.createdAt!.toLocal()),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onEdit,
            child: const Text('Изменить параметры'),
          ),
        ],
      ),
    );
  }
}

class _TaskProperty extends StatelessWidget {
  const _TaskProperty(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 94,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: context.colors.textMutted),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

class TaskDetailsChecklist extends StatelessWidget {
  const TaskDetailsChecklist({
    super.key,
    required this.subtasks,
    required this.onChanged,
  });
  final List<TaskboardTaskSubtask> subtasks;
  final void Function(TaskboardTaskSubtask, bool)? onChanged;

  @override
  Widget build(BuildContext context) {
    if (subtasks.isEmpty) {
      return Text(
        'Подзадач нет.',
        style: TextStyle(fontSize: 12, color: context.colors.textMutted),
      );
    }
    final done = subtasks.where((subtask) => subtask.done).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: done / subtasks.length,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: context.colors.notActiveBorder,
                color: context.colors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$done из ${subtasks.length}',
              style: TextStyle(fontSize: 11, color: context.colors.textMutted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final subtask in subtasks)
          CheckboxListTile(
            key: ValueKey('task-detail-subtask-${subtask.id}'),
            value: subtask.done,
            onChanged: onChanged == null
                ? null
                : (value) {
                    if (value != null) onChanged!(subtask, value);
                  },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: context.colors.activeElement,
            dense: true,
            title: Text(
              subtask.title,
              style: TextStyle(
                fontSize: 13,
                decoration: subtask.done ? TextDecoration.lineThrough : null,
                color: subtask.done
                    ? context.colors.textMutted
                    : context.colors.taskCardText,
              ),
            ),
          ),
      ],
    );
  }
}
