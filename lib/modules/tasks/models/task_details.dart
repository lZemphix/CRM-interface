import 'taskboard.dart';
import 'tasks.dart';

class TaskColumnRef {
  const TaskColumnRef({required this.id, required this.name});
  final int id;
  final String name;

  factory TaskColumnRef.fromApi(Map<String, dynamic> json) =>
      TaskColumnRef(id: json['id'] as int, name: json['name'] as String);
}

class TaskColumnChange {
  const TaskColumnChange({
    required this.previousColumn,
    required this.newColumn,
    required this.changedAt,
    required this.changedBy,
    required this.reason,
  });
  final TaskColumnRef? previousColumn;
  final TaskColumnRef newColumn;
  final DateTime changedAt;
  final TaskEmployee changedBy;
  final String? reason;

  factory TaskColumnChange.fromApi(Map<String, dynamic> json) =>
      TaskColumnChange(
        previousColumn: json['previous_column'] == null
            ? null
            : TaskColumnRef.fromApi(
                Map<String, dynamic>.from(json['previous_column'] as Map),
              ),
        newColumn: TaskColumnRef.fromApi(
          Map<String, dynamic>.from(json['new_column'] as Map),
        ),
        changedAt: DateTime.parse(json['changed_at'] as String),
        changedBy: TaskEmployee.fromApi(
          Map<String, dynamic>.from(json['changed_by'] as Map),
        ),
        reason: json['reason'] as String?,
      );
}

class TaskStatusChange {
  const TaskStatusChange({
    required this.previousStatus,
    required this.newStatus,
    required this.changedAt,
    required this.changedBy,
    required this.reason,
  });
  final String? previousStatus;
  final String newStatus;
  final DateTime changedAt;
  final TaskEmployee changedBy;
  final String? reason;

  factory TaskStatusChange.fromApi(Map<String, dynamic> json) =>
      TaskStatusChange(
        previousStatus: json['previous_status'] as String?,
        newStatus: json['new_status'] as String,
        changedAt: DateTime.parse(json['changed_at'] as String),
        changedBy: TaskEmployee.fromApi(
          Map<String, dynamic>.from(json['changed_by'] as Map),
        ),
        reason: json['reason'] as String?,
      );
}

class TaskAssignmentChange {
  const TaskAssignmentChange({
    required this.previousEmployee,
    required this.newEmployee,
    required this.changedAt,
    required this.changedBy,
    required this.reason,
  });
  final TaskEmployee? previousEmployee;
  final TaskEmployee? newEmployee;
  final DateTime changedAt;
  final TaskEmployee changedBy;
  final String? reason;

  factory TaskAssignmentChange.fromApi(Map<String, dynamic> json) {
    TaskEmployee? employee(Object? json) => json == null
        ? null
        : TaskEmployee.fromApi(Map<String, dynamic>.from(json as Map));
    return TaskAssignmentChange(
      previousEmployee: employee(json['previous_employee']),
      newEmployee: employee(json['new_employee']),
      changedAt: DateTime.parse(json['changed_at'] as String),
      changedBy: TaskEmployee.fromApi(
        Map<String, dynamic>.from(json['changed_by'] as Map),
      ),
      reason: json['reason'] as String?,
    );
  }
}

class TaskDetails {
  const TaskDetails({
    required this.task,
    required this.columnHistory,
    required this.statusHistory,
    required this.assignmentHistory,
    this.author,
    this.createdByEmployeeId,
    this.createdAt,
    this.updatedAt,
  });
  final TaskboardTask task;
  final List<TaskColumnChange> columnHistory;
  final List<TaskStatusChange> statusHistory;
  final List<TaskAssignmentChange> assignmentHistory;
  final TaskEmployee? author;
  final int? createdByEmployeeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskAssignmentChange? get currentAssignment {
    if (task.responsibleEmployeeId == null || assignmentHistory.isEmpty) {
      return null;
    }
    final latest = assignmentHistory.reduce(
      (previous, next) =>
          next.changedAt.isBefore(previous.changedAt) ? previous : next,
    );
    // Never attribute the current executor to an older matching assignment.
    return latest.newEmployee?.id == task.responsibleEmployeeId ? latest : null;
  }

  String? get columnName {
    if (columnHistory.isEmpty) return null;
    final latest = columnHistory.reduce(
      (previous, next) =>
          next.changedAt.isBefore(previous.changedAt) ? previous : next,
    );
    return latest.newColumn.id.toString() == task.columnId
        ? latest.newColumn.name
        : null;
  }

  factory TaskDetails.fromApi(Map<String, dynamic> json) => TaskDetails(
    task: TaskboardTask.fromApi(json),
    author: json['author'] == null
        ? null
        : TaskEmployee.fromApi(
            Map<String, dynamic>.from(json['author'] as Map),
          ),
    createdByEmployeeId: json['created_by_employee_id'] as int?,
    createdAt: json['created_at'] == null
        ? null
        : DateTime.parse(json['created_at'] as String),
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.parse(json['updated_at'] as String),
    columnHistory: (json['column_history'] as List)
        .map(
          (item) =>
              TaskColumnChange.fromApi(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    statusHistory: (json['status_history'] as List)
        .map(
          (item) =>
              TaskStatusChange.fromApi(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    assignmentHistory: (json['assignment_history'] as List)
        .map(
          (item) => TaskAssignmentChange.fromApi(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(),
  );
}
