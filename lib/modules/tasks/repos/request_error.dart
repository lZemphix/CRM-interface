import 'package:dio/dio.dart';

// Keep transport errors in the repository contract; widgets show safe messages.
class TaskRequestException implements Exception {
  const TaskRequestException(this.message);

  final String message;

  factory TaskRequestException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401) {
      return const TaskRequestException('Сессия завершена. Войдите снова.');
    }
    if (status != null && status >= 400 && status < 500) {
      final data = error.response?.data;
      final detail = data is Map ? data['detail'] : null;
      if (detail is Map && detail['message'] is String) {
        final errors = detail['errors'];
        if (errors is List) {
          final messages = <String>[];
          for (final item in errors.take(5)) {
            if (item is! Map || item['message'] is! String) continue;
            final field = item['field'] as String? ?? '';
            final name = _fieldLabel(field);
            messages.add('$name: ${item['message']}');
          }
          if (messages.isNotEmpty) {
            return TaskRequestException(messages.join('\n'));
          }
        }
        return TaskRequestException(detail['message'] as String);
      }
      if (status == 403) {
        return const TaskRequestException(
          'Недостаточно прав для этого действия.',
        );
      }
    }
    return const TaskRequestException(
      'Сервер недоступен или не смог выполнить запрос. Попробуйте ещё раз.',
    );
  }

  static String _fieldLabel(String field) {
    final path = field.replaceFirst(RegExp(r'^body\.'), '');
    return switch (path) {
      'title' => 'Название',
      'name' => 'Название колонки',
      'status' => 'Статус колонки',
      'description' => 'Описание',
      'priority' => 'Важность',
      'column_id' => 'Колонка',
      'responsible_employee_id' => 'Ответственный',
      'due_at' || 'due_date' => 'Срок',
      'customer_id' => 'Клиент',
      'branch_id' => 'Филиал',
      'reason' => 'Причина доработки',
      'subtasks' => 'Подзадачи',
      _ => path.isEmpty ? 'Запрос' : path,
    };
  }

  @override
  String toString() => message;
}
