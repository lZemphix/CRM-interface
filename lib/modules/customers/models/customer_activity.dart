enum CustomerActivityType {
  responsibleChanged('customer.responsible_changed', 'Ответственный клиента'),
  noteCreated('note.created', 'Добавлена заметка'),
  noteUpdated('note.updated', 'Изменена заметка'),
  noteArchived('note.archived', 'Архивирована заметка'),
  taskCreated('task.created', 'Создана задача'),
  taskStatusChanged('task.status_changed', 'Изменён статус задачи'),
  taskResponsibleChanged('task.responsible_changed', 'Ответственный задачи'),
  taskLinked('task.linked', 'Задача связана с клиентом'),
  taskUnlinked('task.unlinked', 'Связь задачи с клиентом снята');

  const CustomerActivityType(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class ActivityEmployee {
  const ActivityEmployee({required this.id, required this.fullName});
  final int id;
  final String fullName;

  factory ActivityEmployee.fromApi(Map<String, dynamic> json) =>
      ActivityEmployee(
        id: json['id'] as int,
        fullName: json['full_name'] as String,
      );

  static ActivityEmployee? nullableFromApi(Object? json) => json == null
      ? null
      : ActivityEmployee.fromApi(Map<String, dynamic>.from(json as Map));
}

/// Поля зависят от события. Тексты заметок сервер намеренно не возвращает.
class CustomerActivityData {
  const CustomerActivityData({
    this.title,
    this.status,
    this.fromStatus,
    this.toStatus,
    this.fromEmployee,
    this.toEmployee,
    this.reason,
  });
  final String? title;
  final String? status;
  final String? fromStatus;
  final String? toStatus;
  final ActivityEmployee? fromEmployee;
  final ActivityEmployee? toEmployee;
  final String? reason;

  factory CustomerActivityData.fromApi(Map<String, dynamic> json) =>
      CustomerActivityData(
        title: json['title'] as String?,
        status: json['status'] as String?,
        fromStatus: json['from_status'] as String?,
        toStatus: json['to_status'] as String?,
        fromEmployee: ActivityEmployee.nullableFromApi(json['from_employee']),
        toEmployee: ActivityEmployee.nullableFromApi(json['to_employee']),
        reason: json['reason'] as String?,
      );
}

class CustomerActivity {
  const CustomerActivity({
    required this.id,
    required this.rawType,
    required this.occurredAt,
    required this.actor,
    required this.entityType,
    required this.entityId,
    required this.data,
  });
  final int id;
  final String rawType;
  final DateTime occurredAt;
  final ActivityEmployee? actor;
  final String entityType;
  final int entityId;
  final CustomerActivityData data;

  CustomerActivityType? get type => CustomerActivityType.values
      .where((type) => type.apiValue == rawType)
      .firstOrNull;

  factory CustomerActivity.fromApi(Map<String, dynamic> json) {
    final entity = Map<String, dynamic>.from(json['entity'] as Map);
    return CustomerActivity(
      id: json['id'] as int,
      rawType: json['type'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      actor: ActivityEmployee.nullableFromApi(json['actor']),
      entityType: entity['type'] as String,
      entityId: entity['id'] as int,
      data: CustomerActivityData.fromApi(
        Map<String, dynamic>.from(json['data'] as Map),
      ),
    );
  }
}

class CustomerActivityPage {
  const CustomerActivityPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });
  final List<CustomerActivity> items;
  final int total;
  final int limit;
  final int offset;

  factory CustomerActivityPage.fromApi(Map<String, dynamic> json) =>
      CustomerActivityPage(
        items: (json['items'] as List)
            .map(
              (item) => CustomerActivity.fromApi(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        total: json['total'] as int,
        limit: json['limit'] as int,
        offset: json['offset'] as int,
      );
}
