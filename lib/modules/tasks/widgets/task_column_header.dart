import 'package:crm_interface/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

import 'column_decoration.dart';

enum TaskColumnAction { rename, archive }

class TaskColumnHeader extends StatelessWidget {
  const TaskColumnHeader({
    super.key,
    required this.title,
    required this.taskCount,
    this.onAction,
  });

  final String title;
  final int taskCount;
  final ValueChanged<TaskColumnAction>? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: title,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.taskCardText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Semantics(
                label: 'Задач в колонке: $taskCount',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.background,
                    border: Border.all(color: context.colors.notActiveBorder),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$taskCount',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMutted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 28,
                height: 28,
                child: PopupMenuButton<TaskColumnAction>(
                  tooltip: 'Действия с колонкой',
                  enabled: onAction != null,
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(7),
                  color: context.colors.surface,
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
                      value: TaskColumnAction.rename,
                      child: Text('Переименовать'),
                    ),
                    PopupMenuItem(
                      value: TaskColumnAction.archive,
                      child: Text(
                        'Архивировать',
                        style: TextStyle(color: context.colors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (taskCount == 0) ...[
            const SizedBox(height: 10),
            CustomPaint(
              foregroundPainter: DashedColumnBorder(
                color: context.colors.strongBorder,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 22,
                ),
                child: Text(
                  'Перетащите задачу сюда',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textMutted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
