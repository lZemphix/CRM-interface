import 'package:appflowy_board/appflowy_board.dart';
import 'package:crm_interface/core/theme/app_palette.dart';
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
    this.onOpen,
    this.compact = false,
    this.currentEmployeeId,
  });

  final TaskboardTask task;
  final bool compact;
  final int? currentEmployeeId;
  final ValueChanged<TaskCardAction>? onAction;
  final VoidCallback? onOpen;
  final Future<void> Function(TaskboardTaskSubtask, bool)? onSubtaskChanged;

  @override
  Widget build(BuildContext context) {
    final description = task.description?.trim();

    if (compact) return _buildCompactCard(context, description);
    final isMine =
        currentEmployeeId != null &&
        task.responsibleEmployeeId == currentEmployeeId;

    return AppFlowyGroupCard(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      decoration: BoxDecoration(
        color: isMine
            ? context.colors.ownTaskBackground
            : context.colors.taskCardBackground,
        border: Border.all(
          color: isMine
              ? context.colors.ownTaskBorder
              : context.colors.notActiveBorder,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.colors.taskCardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: _withOpen(
        context,
        _withOwnAccent(
          context,
          isMine,
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeading(context),
                if (task.status != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _statusLabel(),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textMutted,
                    ),
                  ),
                ],
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDescription(context, description),
                ],
                const SizedBox(height: 12),
                _buildAssignee(context, isMine: isMine),
                if (task.customerId != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: context.colors.textMutted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          task.customerName ?? 'Клиент #${task.customerId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textMutted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (task.dueAt != null || task.dueDate != null) ...[
                  const SizedBox(height: 6),
                  _buildDeadline(context),
                ],
                const SizedBox(height: 12),
                _buildProgress(context),
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
        ),
      ),
    );
  }

  Widget _withOpen(BuildContext context, Widget child) => Material(
    type: MaterialType.transparency,
    borderRadius: BorderRadius.circular(11),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(11),
      child: child,
    ),
  );

  Widget _withOwnAccent(BuildContext context, bool isMine, Widget child) {
    return ClipRRect(
      // Keep the subtree stable when the profile/assignment changes.
      clipBehavior: isMine ? Clip.antiAlias : Clip.none,
      borderRadius: BorderRadius.circular(11),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(
              color: isMine ? context.colors.ownTaskAccent : Colors.transparent,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context, String? description) {
    return Material(
      color: context.colors.taskCardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: context.colors.notActiveBorder),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.taskCardText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPriority(context),
                  const SizedBox(width: 8),
                  _buildActionMenu(context),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMutted,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _buildCompactMetadata(context),
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
      ),
    );
  }

  Widget _buildCompactMetadata(BuildContext context) {
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
                color: context.colors.background,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _statusLabel(),
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textMutted,
                ),
              ),
            ),
            SizedBox(width: assigneeWidth, child: _buildAssignee(context)),
            if (task.dueAt != null || task.dueDate != null)
              SizedBox(width: deadlineWidth, child: _buildDeadline(context)),
            if (task.subtasks.isNotEmpty)
              SizedBox(
                width: constraints.maxWidth.clamp(0.0, 100.0).toDouble(),
                child: _buildProgress(context, showMenu: false),
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

  Widget _buildHeading(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final title = Tooltip(
          message: task.title,
          child: Text(
            task.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: context.colors.taskCardText,
            ),
          ),
        );
        if (constraints.maxWidth < 200) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 6),
              _buildPriority(context),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 8),
            _buildPriority(context),
          ],
        );
      },
    );
  }

  Widget _buildPriority(BuildContext context) {
    String label;
    Color color;
    switch (task.priority) {
      case 'low':
        label = 'Низкая';
        color = context.colors.textMutted;
      case 'normal':
        label = 'Обычная';
        color = context.colors.normalPriority;
      case 'high':
        label = 'Высокая';
        color = context.colors.taskHighPriority;
      case 'urgent':
        label = 'Срочная';
        color = context.colors.taskUrgentPriority;
      default:
        label = 'Неизвестный';
        color = context.colors.textMutted;
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

  Widget _buildDescription(BuildContext context, String description) {
    return Tooltip(
      message: description,
      child: Text(
        description,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          color: context.colors.textMutted,
        ),
      ),
    );
  }

  Widget _buildAssignee(BuildContext context, {bool isMine = false}) {
    final name = task.responsibleEmployeeName?.trim();
    String label = 'Без ответственного';
    if (name != null && name.isNotEmpty) {
      label = name;
    } else if (task.responsibleEmployeeId != null) {
      label = 'Сотрудник #${task.responsibleEmployeeId}';
    }
    if (!isMine) {
      return _buildMetadataLine(context, Icons.person_outline_rounded, label);
    }
    return Tooltip(
      message: 'Назначено вам · $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: context.colors.ownTaskBadgeBackground,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          'Вам · $label',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.colors.ownTaskText,
          ),
        ),
      ),
    );
  }

  Widget _buildDeadline(BuildContext context) {
    final day = task.dueDate;
    if (day != null) {
      final label = 'Срок: ${DateFormat('dd.MM.yyyy').format(day)}';
      return _buildMetadataLine(
        context,
        Icons.calendar_today_outlined,
        label,
        tooltip:
            '$label (весь день${task.timezone == null ? '' : ', ${task.timezone}'})',
      );
    }
    final localDate = task.dueAt!.toLocal();
    final label = 'Срок: ${DateFormat('dd.MM.yyyy HH:mm').format(localDate)}';
    return _buildMetadataLine(
      context,
      Icons.schedule_rounded,
      label,
      tooltip: '$label (время этого устройства)',
    );
  }

  Widget _buildMetadataLine(
    BuildContext context,
    IconData icon,
    String label, {
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? label,
      child: Row(
        children: [
          Icon(icon, size: 14, color: context.colors.textMutted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: context.colors.textMutted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(BuildContext context, {bool showMenu = true}) {
    final total = task.subtasks.length;
    final completed = task.subtasks.where((subtask) => subtask.done).length;
    final progress = total == 0 ? 0.0 : completed / total;

    final indicator = LinearProgressIndicator(
      value: progress,
      minHeight: 6,
      borderRadius: BorderRadius.circular(99),
      color: context.colors.accent,
      backgroundColor: context.colors.notActiveBorder,
      semanticsLabel: 'Подзадачи: выполнено $completed из $total',
    );
    final label = Text(
      total == 0 ? 'Без подзадач' : '$completed/$total',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, color: context.colors.textMutted),
    );
    return LayoutBuilder(
      builder: (_, constraints) {
        if (showMenu && constraints.maxWidth < 180) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 6),
                  _buildActionMenu(context),
                ],
              ),
              const SizedBox(height: 4),
              indicator,
            ],
          );
        }
        return Row(
          children: [
            label,
            const SizedBox(width: 10),
            Expanded(child: indicator),
            if (showMenu) ...[
              const SizedBox(width: 9),
              _buildActionMenu(context),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<TaskCardAction>(
        tooltip: 'Действия с задачей',
        enabled: onAction != null,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(7),
        constraints: const BoxConstraints(minWidth: 190, maxWidth: 250),
        color: context.colors.surface,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: context.colors.notActiveBorder),
        ),
        icon: Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: context.colors.textMutted,
        ),
        onSelected: onAction,
        itemBuilder: (_) => [
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
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textMutted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
