import 'package:crm_interface/core/theme/light/colorscheme.dart';
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 11),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.taskCardText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Задач в колонке: $taskCount',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.notActiveBorder),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$taskCount',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMutted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                height: 28,
                child: PopupMenuButton<TaskColumnAction>(
                  tooltip: 'Действия с колонкой',
                  enabled: onAction != null,
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(7),
                  color: Colors.white,
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
                      value: TaskColumnAction.rename,
                      child: Text('Переименовать'),
                    ),
                    PopupMenuItem(
                      value: TaskColumnAction.archive,
                      child: Text(
                        'Архивировать',
                        style: TextStyle(color: Color(0xFFB42318)),
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
              foregroundPainter: const DashedColumnBorder(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 22,
                ),
                child: const Text(
                  'Перетащите задачу сюда',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMutted),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
