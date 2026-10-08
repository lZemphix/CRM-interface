import 'package:appflowy_board/appflowy_board.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'task_subtasks.dart';

enum TaskCardAction { edit, assign, history, delete }

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.onSubtaskChanged,
    this.onAction,
    this.compact = false,
  });

  final TaskboardTask task;
  final bool compact;
  final ValueChanged<TaskCardAction>? onAction;
  final Future<void> Function(TaskboardTaskSubtask, bool)? onSubtaskChanged;

  @override
  Widget build(BuildContext context) {
    final description = task.description?.trim();

    if (compact) return _buildCompactCard(description);

    return AppFlowyGroupCard(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.taskCardBackground,
        border: Border.all(color: AppColors.notActiveBorder),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: AppColors.taskCardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeading(),
            if (task.status != null) ...[
              const SizedBox(height: 5),
              Text(
                _statusLabel(),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMutted,
                ),
              ),
            ],
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildDescription(description),
            ],
            const SizedBox(height: 12),
            _buildAssignee(),
            if (task.customerId != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppColors.textMutted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.customerName ?? 'Клиент #${task.customerId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMutted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (task.dueAt != null || task.dueDate != null) ...[
              const SizedBox(height: 6),
              _buildDeadline(),
            ],
            const SizedBox(height: 12),
            _buildProgress(),
            if (task.subtasks.isNotEmpty) ...[
              const SizedBox(height: 10),
              TaskSubtasks(
                taskId: task.id,
                subtasks: task.subtasks,
                onChanged: onSubtaskChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(String? description) {
    return Material(
      color: AppColors.taskCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.notActiveBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: task.title,
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.taskCardText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildPriority(),
                const SizedBox(width: 8),
                _buildActionMenu(),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Tooltip(
                message: description,
                child: Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMutted,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            _buildCompactMetadata(),
            if (task.subtasks.isNotEmpty) ...[
              const SizedBox(height: 6),
              TaskSubtasks(
                taskId: task.id,
                subtasks: task.subtasks,
                onChanged: onSubtaskChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMetadata() {
    return LayoutBuilder(
      builder: (_, constraints) {
        // Bound metadata in Wrap: the existing lines contain an Expanded.
        final assigneeWidth = constraints.maxWidth.clamp(0.0, 180.0).toDouble();
        final deadlineWidth = constraints.maxWidth.clamp(0.0, 190.0).toDouble();
        return Wrap(
          spacing: 14,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _statusLabel(),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMutted,
                ),
              ),
            ),
            SizedBox(width: assigneeWidth, child: _buildAssignee()),
            if (task.dueAt != null || task.dueDate != null)
              SizedBox(width: deadlineWidth, child: _buildDeadline()),
            if (task.subtasks.isNotEmpty)
              SizedBox(
                width: constraints.maxWidth.clamp(0.0, 100.0).toDouble(),
                child: _buildProgress(showMenu: false),
              ),
          ],
        );
      },
    );
  }

  String _statusLabel() => switch (task.status) {
    'new' => 'Новая',
    'in_progress' => 'В работе',
    'rework' => 'Доработка',
    'completed' => 'Выполнена — на проверке',
    'confirmed' => 'Подтверждена',
    'cancelled' => 'Отменена',
    _ => 'Статус неизвестен',
  };

  Widget _buildHeading() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Tooltip(
            message: task.title,
            child: Text(
              task.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: AppColors.taskCardText,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildPriority(),
      ],
    );
  }

  Widget _buildPriority() {
    String label;
    Color color;
    switch (task.priority) {
      case 'low':
        label = 'Низкая';
        color = AppColors.textMutted;
      case 'normal':
        label = 'Обычная';
        color = AppColors.activeElement;
      case 'high':
        label = 'Высокая';
        color = AppColors.taskHighPriority;
      case 'urgent':
        label = 'Срочная';
        color = AppColors.taskUrgentPriority;
      default:
        label = 'Неизвестный';
        color = AppColors.textMutted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDescription(String description) {
    return Tooltip(
      message: description,
      child: Text(
        description,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          height: 1.45,
          color: AppColors.textMutted,
        ),
      ),
    );
  }

  Widget _buildAssignee() {
    final name = task.responsibleEmployeeName?.trim();
    String label = 'Без ответственного';
    if (name != null && name.isNotEmpty) {
      label = name;
    } else if (task.responsibleEmployeeId != null) {
      label = 'Сотрудник #${task.responsibleEmployeeId}';
    }
    return _buildMetadataLine(Icons.person_outline_rounded, label);
  }

  Widget _buildDeadline() {
    final day = task.dueDate;
    if (day != null) {
      final label = 'Срок: ${DateFormat('dd.MM.yyyy').format(day)}';
      return _buildMetadataLine(
        Icons.calendar_today_outlined,
        label,
        tooltip:
            '$label (весь день${task.timezone == null ? '' : ', ${task.timezone}'})',
      );
    }
    final localDate = task.dueAt!.toLocal();
    final label = 'Срок: ${DateFormat('dd.MM.yyyy HH:mm').format(localDate)}';
    return _buildMetadataLine(
      Icons.schedule_rounded,
      label,
      tooltip: '$label (время этого устройства)',
    );
  }

  Widget _buildMetadataLine(IconData icon, String label, {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? label,
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMutted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMutted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress({bool showMenu = true}) {
    final total = task.subtasks.length;
    final completed = task.subtasks.where((subtask) => subtask.done).length;
    final progress = total == 0 ? 0.0 : completed / total;

    return Row(
      children: [
        Text(
          total == 0 ? 'Без подзадач' : '$completed/$total',
          style: const TextStyle(fontSize: 11, color: AppColors.textMutted),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(99),
            color: AppColors.activeElement,
            backgroundColor: AppColors.notActiveBorder,
            semanticsLabel: 'Подзадачи: выполнено $completed из $total',
          ),
        ),
        if (showMenu) ...[const SizedBox(width: 9), _buildActionMenu()],
      ],
    );
  }

  Widget _buildActionMenu() {
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<TaskCardAction>(
        tooltip: 'Действия с задачей',
        enabled: onAction != null,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(7),
        constraints: const BoxConstraints(minWidth: 190, maxWidth: 250),
        color: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.notActiveBorder),
        ),
        icon: const Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: AppColors.textMutted,
        ),
        onSelected: onAction,
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: TaskCardAction.history,
            height: 34,
            child: Text('История задачи', style: TextStyle(fontSize: 12)),
          ),
          PopupMenuItem(
            value: TaskCardAction.edit,
            height: 34,
            child: Text('Редактировать', style: TextStyle(fontSize: 12)),
          ),
          PopupMenuItem(
            value: TaskCardAction.assign,
            height: 34,
            child: Text(
              'Назначить ответственного',
              style: TextStyle(fontSize: 12),
            ),
          ),
          PopupMenuItem(
            value: TaskCardAction.delete,
            height: 34,
            enabled: false,
            child: Tooltip(
              message:
                  'Удаление и архивирование задач ещё не поддерживаются API',
              child: Text(
                'Удалить задачу',
                style: TextStyle(fontSize: 12, color: AppColors.textMutted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
