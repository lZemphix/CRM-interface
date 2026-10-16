import 'package:appflowy_board/appflowy_board.dart';
import 'package:flutter/foundation.dart';

import '../models/taskboard.dart';

class TasksCanbanCard extends AppFlowyGroupItem {
  TasksCanbanCard({required this.task});

  final TaskboardTask task;

  @override
  String get id => task.id;
}

/// Reconcile a server snapshot without clearing controllers or unchanged cards.
/// Both polling and a future push notification can use this same path.
/// Returns whether controller data changed; equal snapshots send no notifications.
bool synchronizeTaskBoard(AppFlowyBoardController controller, Taskboard board) {
  var changed = false;
  final columnIds = board.columns.map((column) => column.id).toSet();
  final tasksById = {for (final task in board.tasks) task.id: task};

  for (final id in controller.groupIds.toList()) {
    if (!columnIds.contains(id)) {
      controller.removeGroup(id);
      changed = true;
    }
  }
  for (var index = 0; index < board.columns.length; index++) {
    final column = board.columns[index];
    if (!controller.groupIds.contains(column.id)) {
      controller.insertGroup(
        index,
        AppFlowyGroupData(id: column.id, name: column.name, items: []),
      );
      changed = true;
    } else {
      final currentIndex = controller.groupIds.indexOf(column.id);
      if (currentIndex != index) {
        controller.moveGroup(currentIndex, index);
        changed = true;
      }
      final group = controller.getGroupController(column.id)!;
      if (group.groupData.headerData.groupName != column.name) {
        group.updateGroupName(column.name);
        changed = true;
      }
    }
  }

  for (final group in controller.groupDatas) {
    for (final item in group.items.toList()) {
      if (tasksById[item.id]?.columnId != group.id) {
        controller.removeGroupItem(group.id, item.id);
        changed = true;
      }
    }
    final tasks = board.tasks
        .where((task) => task.columnId == group.id)
        .toList();
    final groupController = controller.getGroupController(group.id)!;
    for (var index = 0; index < tasks.length; index++) {
      final task = tasks[index];
      final currentIndex = groupController.items.indexWhere(
        (item) => item.id == task.id,
      );
      if (currentIndex == -1) {
        controller.insertGroupItem(
          group.id,
          index,
          TasksCanbanCard(task: task),
        );
        changed = true;
      } else {
        if (currentIndex != index) {
          groupController.move(currentIndex, index);
          changed = true;
        }
        final current = groupController.items[index] as TasksCanbanCard;
        if (!_sameTask(current.task, task)) {
          controller.updateGroupItem(group.id, TasksCanbanCard(task: task));
          changed = true;
        }
      }
    }
  }
  return changed;
}

bool sameTaskBoardColumns(
  List<TaskboardColumn> a,
  List<TaskboardColumn> b,
) => listEquals(
  a
      .map((c) => (c.id, c.name, c.order, c.countsAsDone, c.status, c.version))
      .toList(),
  b
      .map((c) => (c.id, c.name, c.order, c.countsAsDone, c.status, c.version))
      .toList(),
);

bool _sameTask(TaskboardTask a, TaskboardTask b) =>
    (
          a.id,
          a.columnId,
          a.title,
          a.description,
          a.priority,
          a.responsibleEmployeeId,
          a.responsibleEmployeeName,
          a.dueAt,
          a.dueDate,
          a.timezone,
          a.customerId,
          a.customerName,
          a.status,
          a.branchId,
          a.version,
        ) ==
        (
          b.id,
          b.columnId,
          b.title,
          b.description,
          b.priority,
          b.responsibleEmployeeId,
          b.responsibleEmployeeName,
          b.dueAt,
          b.dueDate,
          b.timezone,
          b.customerId,
          b.customerName,
          b.status,
          b.branchId,
          b.version,
        ) &&
    listEquals(
      a.subtasks.map((s) => (s.id, s.title, s.done, s.order)).toList(),
      b.subtasks.map((s) => (s.id, s.title, s.done, s.order)).toList(),
    );
