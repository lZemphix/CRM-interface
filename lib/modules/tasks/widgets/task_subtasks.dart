import 'package:flutter/material.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';

import '../models/taskboard.dart';
import '../repos/request_error.dart';

class TaskSubtasks extends StatefulWidget {
  const TaskSubtasks({
    super.key,
    required this.taskId,
    required this.subtasks,
    this.onChanged,
  });

  final String taskId;
  final List<TaskboardTaskSubtask> subtasks;
  final Future<void> Function(TaskboardTaskSubtask, bool)? onChanged;

  @override
  State<TaskSubtasks> createState() => _TaskSubtasksState();
}

class _TaskSubtasksState extends State<TaskSubtasks> {
  bool _saving = false;
  String? _error;

  Future<void> _mark(TaskboardTaskSubtask subtask, bool done) async {
    if (_saving || widget.onChanged == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onChanged!(subtask, done);
    } on TaskRequestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось сохранить подзадачу. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTileTheme(
      data: const ListTileThemeData(
        minVerticalPadding: 0,
        minLeadingWidth: 18,
        horizontalTitleGap: 7,
      ),
      child: ExpansionTile(
        key: PageStorageKey('task-${widget.taskId}-subtasks'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        dense: true,
        minTileHeight: 26,
        visualDensity: VisualDensity.compact,
        controlAffinity: ListTileControlAffinity.leading,
        showTrailingIcon: true,
        shape: const Border(top: BorderSide(color: AppColors.notActiveBorder)),
        collapsedShape: const Border(
          top: BorderSide(color: AppColors.notActiveBorder),
        ),
        title: Text(
          'Подзадачи · ${widget.subtasks.where((item) => item.done).length}/${widget.subtasks.length}',
          style: const TextStyle(fontSize: 11, color: AppColors.activeElement),
        ),
        children: [
          for (final subtask in widget.subtasks)
            CheckboxListTile(
              key: ValueKey(subtask.id),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              minTileHeight: 26,
              checkboxScaleFactor: .75,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              activeColor: AppColors.activeElement,
              value: subtask.done,
              title: Text(
                subtask.title,
                style: TextStyle(
                  fontSize: 12,
                  color: subtask.done
                      ? AppColors.textMutted
                      : AppColors.taskCardText,
                  decoration: subtask.done ? TextDecoration.lineThrough : null,
                ),
              ),
              onChanged: _saving || widget.onChanged == null
                  ? null
                  : (done) {
                      if (done != null) _mark(subtask, done);
                    },
            ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
