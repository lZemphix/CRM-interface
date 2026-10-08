class CreateTaskRequest {
  const CreateTaskRequest({
    required this.columnId,
    required this.title,
    this.description = '',
    required this.priority,
    required this.responsibleEmployeeId,
    this.dueAt,
    this.customerId,
    this.branchId,
    this.reason,
    required this.subtasks,
  });

  final int columnId;
  final String title;
  final String description;
  final Priority priority;
  final int? responsibleEmployeeId;
  final DateTime? dueAt;
  final int? customerId;
  final int? branchId;
  final String? reason;
  final List<Subtask> subtasks;

  String currentPriority(Priority prio) {
    switch (prio) {
      case Priority.low:
        return 'low';
      case Priority.normal:
        return 'normal';
      case Priority.high:
        return 'high';
      case Priority.urgent:
        return 'urgent';
    }
  }

  Map<String, dynamic> toApi() {
    return {
      "column_id": columnId,
      "title": title,
      "description": description,
      "priority": currentPriority(priority),
      "responsible_employee_id": responsibleEmployeeId,
      "due_at": dueAt?.toUtc().toIso8601String(),
      "customer_id": customerId,
      "branch_id": branchId,
      if (reason != null) "reason": reason,
      "subtasks": subtasks.map((subtask) => subtask.toApi()).toList(),
    };
  }
}

class Subtask {
  final String title;

  const Subtask({required this.title});

  Map<String, String> toApi() {
    return {'title': title};
  }
}

enum Priority { low, normal, high, urgent }

class MarkSubtaskRequest {
  const MarkSubtaskRequest({required this.done, required this.version});

  final bool done;
  final int version;

  Map<String, dynamic> toApi() => {'done': done, 'version': version};
}

class MoveTaskRequest {
  const MoveTaskRequest({
    required this.columnId,
    required this.version,
    this.reason,
  });

  final int columnId;
  final int version;
  final String? reason;

  Map<String, dynamic> toApi() => {
    'column_id': columnId,
    'version': version,
    if (reason != null) 'reason': reason,
  };
}

class EditTaskRequest {
  const EditTaskRequest({
    required this.title,
    required this.description,
    required this.priority,
    required this.version,
    this.customerId,
    this.updateCustomer = false,
  });

  final String title;
  final String description;
  final Priority priority;
  final int version;
  final int? customerId;
  final bool updateCustomer;

  Map<String, dynamic> toApi() => {
    'title': title,
    'description': description,
    'priority': priority.name,
    'version': version,
    // Отсутствие поля сохраняет привязку; explicit null снимает её.
    if (updateCustomer) 'customer_id': customerId,
  };
}

class AssignTaskRequest {
  const AssignTaskRequest({required this.employeeId, this.reason});

  final int? employeeId;
  final String? reason;

  Map<String, dynamic> toApi() => {
    'employee_id': employeeId,
    if (reason != null) 'reason': reason,
  };
}

class TaskEmployee {
  const TaskEmployee({required this.id, required this.fullName});

  final int id;
  final String fullName;

  factory TaskEmployee.fromApi(Map<String, dynamic> json) {
    return TaskEmployee(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
    );
  }
}

class TaskCustomerOption {
  const TaskCustomerOption({
    required this.id,
    required this.fullName,
    this.primaryContact,
  });

  final int id;
  final String fullName;
  final String? primaryContact;

  factory TaskCustomerOption.fromApi(Map<String, dynamic> json) =>
      TaskCustomerOption(
        id: json['id'] as int,
        fullName: json['full_name'] as String,
        primaryContact: json['primary_contact'] as String?,
      );
}
