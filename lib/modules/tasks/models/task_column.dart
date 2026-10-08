enum TaskColumnStatus {
  newTask('new', 'Новая'),
  inProgress('in_progress', 'В работе'),
  completed('completed', 'Выполнена — на проверке'),
  rework('rework', 'На доработке'),
  confirmed('confirmed', 'Подтверждена'),
  cancelled('cancelled', 'Отменена');

  const TaskColumnStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class CreateTaskColumnRequest {
  const CreateTaskColumnRequest({required this.name, this.status});

  final String name;
  final TaskColumnStatus? status;

  Map<String, dynamic> toApi() => {'name': name, 'status': status?.apiValue};
}

class RenameTaskColumnRequest {
  const RenameTaskColumnRequest({required this.name, required this.version});

  final String name;
  final int version;

  Map<String, dynamic> toApi() => {'name': name, 'version': version};
}
