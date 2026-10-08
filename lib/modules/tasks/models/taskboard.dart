class Taskboard {
  const Taskboard({
    required this.columns,
    required this.tasks,
    this.truncated = false,
  });

  final List<TaskboardColumn> columns;
  final List<TaskboardTask> tasks;
  final bool truncated;

  factory Taskboard.fromApi(Map<String, dynamic> json) {
    final columns = json['columns'];
    final tasks = json['tasks'];

    if (columns is! List || tasks is! List) {
      throw FormatException('Incorrect type of taskboard');
    }

    return Taskboard(
      columns: columns
          .map(
            (column) =>
                TaskboardColumn.fromApi(Map<String, dynamic>.from(column)),
          )
          .toList(),
      tasks: tasks
          .map((task) => TaskboardTask.fromApi(Map<String, dynamic>.from(task)))
          .toList(),
      truncated: json['truncated'] as bool,
    );
  }
}

class TaskboardColumn {
  final String id;
  final String name;
  final int order;
  final bool countsAsDone;
  final String? status;
  final int version;

  const TaskboardColumn({
    required this.id,
    required this.name,
    required this.order,
    required this.countsAsDone,
    required this.status,
    required this.version,
  });

  factory TaskboardColumn.fromApi(Map<String, dynamic> json) {
    return TaskboardColumn(
      id: json['id'].toString(),
      name: json['name'] as String,
      order: json['order'] as int,
      countsAsDone: json['counts_as_done'] as bool,
      status: json['status'] as String?,
      version: json['version'] as int,
    );
  }

  // Unknown future statuses must not silently behave as new tasks.
  bool get canCreateTask =>
      status == null ||
      const {'new', 'in_progress', 'completed', 'rework'}.contains(status);

  bool get requiresExecutor => status == 'in_progress' || status == 'completed';
  bool get requiresReason => status == 'rework';
}

class TaskboardTask {
  const TaskboardTask({
    required this.id,
    required this.columnId,
    required this.title,
    required this.description,
    required this.priority,
    this.responsibleEmployeeId,
    this.responsibleEmployeeName,
    this.dueAt,
    this.dueDate,
    this.timezone,
    this.customerId,
    this.customerName,
    this.status,
    this.branchId,
    required this.subtasks,
    required this.version,
  });

  final String id;
  final String columnId;
  final String title;
  final String? description;
  final String priority;
  final int? responsibleEmployeeId;
  final String? responsibleEmployeeName;
  final DateTime? dueAt;
  final DateTime? dueDate;
  final String? timezone;
  final int? customerId;
  final String? customerName;
  final String? status;
  final int? branchId;
  final List<TaskboardTaskSubtask> subtasks;
  final int version;

  factory TaskboardTask.fromApi(Map<String, dynamic> json) {
    final rawSubtasks = json['subtasks'] as List;
    final formatedSubtasks = rawSubtasks
        .map(
          (subtask) => TaskboardTaskSubtask.fromApi(
            Map<String, dynamic>.from(subtask as Map),
          ),
        )
        .toList();

    final rawDueAt = json['due_at'] as String?;
    final rawCustomer = json['customer'] as Map?;
    final rawResponsible = json['responsible'] as Map?;

    return TaskboardTask(
      id: json['id'].toString(),
      columnId: json['column_id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String?,
      priority: json['priority'] as String,
      responsibleEmployeeId: json['responsible_employee_id'] as int?,
      responsibleEmployeeName: rawResponsible?['full_name'] as String?,
      dueAt: rawDueAt == null ? null : DateTime.parse(rawDueAt),
      dueDate: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
      timezone: json['timezone'] as String?,
      customerId: rawCustomer?['id'] as int?,
      customerName: rawCustomer?['full_name'] as String?,
      status: json['status'] as String?,
      branchId: json['branch_id'] as int?,
      subtasks: formatedSubtasks,
      version: json['version'] as int,
    );
  }
}

class TaskPage {
  const TaskPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<TaskboardTask> items;
  final int total;
  final int limit;
  final int offset;

  factory TaskPage.fromApi(Map<String, dynamic> json) => TaskPage(
    items: (json['items'] as List)
        .map(
          (item) =>
              TaskboardTask.fromApi(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    total: json['total'] as int,
    limit: json['limit'] as int,
    offset: json['offset'] as int,
  );
}

class TaskboardTaskSubtask {
  const TaskboardTaskSubtask({
    required this.id,
    required this.title,
    required this.done,
    required this.order,
  });
  final int id;
  final String title;
  final bool done;
  final int order;

  factory TaskboardTaskSubtask.fromApi(Map<String, dynamic> json) {
    return TaskboardTaskSubtask(
      id: json['id'] as int,
      title: json['title'] as String,
      done: json['done'] as bool,
      order: json['order'] as int,
    );
  }
}
