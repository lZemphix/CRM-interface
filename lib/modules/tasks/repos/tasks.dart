import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/models/task_column.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:dio/dio.dart';
import 'package:crm_interface/core/api_client/client.dart';

import 'request_error.dart';
import '../models/task_details.dart';

class TasksRepository {
  const TasksRepository(this.apiClient);

  final ApiClient apiClient;

  Future<TaskDetails> getTaskDetails(String taskId) async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        '/tasks/$taskId',
      );
      if (response.data == null) {
        throw const FormatException('Empty task details');
      }
      return TaskDetails.fromApi(response.data!);
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    } on FormatException {
      throw const TaskRequestException('Некорректная история задачи');
    } on TypeError {
      throw const TaskRequestException('Некорректная история задачи');
    }
  }

  Future<List<TaskCustomerOption>> searchCustomers(String search) async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        '/customers',
        queryParameters: {
          'search': search.trim(),
          'status': 'active',
          'limit': 20,
          'offset': 0,
        },
      );
      final items = response.data?['items'];
      if (items is! List) {
        throw const FormatException('Invalid customer search response');
      }
      return items
          .map(
            (item) => TaskCustomerOption.fromApi(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    }
  }

  Future<List<TaskboardColumn>> getColumns() async {
    try {
      final response = await apiClient.dio.get<List<dynamic>>('/task-columns');
      if (response.data == null) {
        throw const FormatException('Empty columns response');
      }
      return response.data!
          .map(
            (item) =>
                TaskboardColumn.fromApi(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    }
  }

  Future<TaskPage> getCustomerTasks(
    int customerId, {
    int limit = 20,
    int offset = 0,
    String sort = 'due_at',
  }) async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        '/tasks',
        queryParameters: {
          'customer_id': customerId,
          'limit': limit,
          'offset': offset,
          'sort': sort,
        },
      );
      if (response.data == null) {
        throw const FormatException('Empty task list response');
      }
      return TaskPage.fromApi(response.data!);
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    }
  }

  Future<TaskboardTask?> getClosestCustomerTask(int customerId) async {
    var offset = 0;
    while (true) {
      // API sorts deadlines ascending (nulls last), with ID as a tie-breaker.
      // Completed tasks awaiting confirmation can occupy an entire page.
      final page = await getCustomerTasks(customerId, offset: offset);
      for (final task in page.items) {
        if (task.customerId == customerId &&
            const {'new', 'in_progress', 'rework'}.contains(task.status)) {
          return task;
        }
      }
      offset += page.items.length;
      if (page.items.isEmpty || offset >= page.total) return null;
    }
  }

  Future<TaskboardTask> startTask(String taskId) =>
      _changeTaskStatus(taskId, 'in_progress');

  Future<TaskboardTask> moveTask(String taskId, MoveTaskRequest request) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        '/tasks/$taskId/move',
        data: request.toApi(),
        options: Options(contentType: Headers.jsonContentType),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const FormatException('Task move response is invalid');
      }
      return TaskboardTask.fromApi(response.data!);
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    } on TypeError {
      throw const FormatException('Task move response is invalid');
    }
  }

  Future<TaskboardTask> completeTask(String taskId) =>
      _changeTaskStatus(taskId, 'completed');

  Future<TaskboardTask> _changeTaskStatus(String taskId, String status) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        '/tasks/$taskId/status',
        data: {'status': status},
        options: Options(contentType: Headers.jsonContentType),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const FormatException('Task status response is invalid');
      }
      return TaskboardTask.fromApi(response.data!);
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    }
  }

  Future<Taskboard> getTaskBoard() async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        "/task-board",
      );

      final data = response.data;

      if (data == null) {
        throw Exception('Tasks board has no data');
      }

      return Taskboard.fromApi(data);
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    }
  }

  Future<TaskboardTask> createTask(CreateTaskRequest task) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        "/tasks",
        data: task.toApi(),
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = response.data;

      if (response.statusCode != 201 || data == null) {
        throw const FormatException('Task creation response is invalid');
      }
      return TaskboardTask.fromApi(data);
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    }
  }

  Future<TaskboardTask> markSubtask(
    String taskId,
    int subtaskId,
    MarkSubtaskRequest request,
  ) async {
    try {
      final response = await apiClient.dio.patch<Map<String, dynamic>>(
        '/tasks/$taskId/subtasks/$subtaskId',
        data: request.toApi(),
        options: Options(contentType: Headers.jsonContentType),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const FormatException('Subtask update response is invalid');
      }
      return TaskboardTask.fromApi(response.data!);
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    }
  }

  Future<TaskboardTask> editTask(String taskId, EditTaskRequest request) async {
    try {
      final response = await apiClient.dio.patch<Map<String, dynamic>>(
        '/tasks/$taskId',
        data: request.toApi(),
        options: Options(contentType: Headers.jsonContentType),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const FormatException('Task update response is invalid');
      }
      return TaskboardTask.fromApi(response.data!);
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    }
  }

  Future<TaskboardTask> assignTask(
    String taskId,
    AssignTaskRequest request,
  ) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        '/tasks/$taskId/assign',
        data: request.toApi(),
        options: Options(contentType: Headers.jsonContentType),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const FormatException('Task assignment response is invalid');
      }
      return TaskboardTask.fromApi(response.data!);
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    }
  }

  Future<TaskboardColumn> createColumn(CreateTaskColumnRequest column) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        '/task-columns',
        data: column.toApi(),
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = response.data;
      if (response.statusCode != 201 || data == null) {
        throw const FormatException('Column creation response is invalid');
      }
      return TaskboardColumn.fromApi(data);
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    }
  }

  Future<List<TaskEmployee>> getEmployees() async {
    final response = await apiClient.dio.get<List<dynamic>>('/employees');
    final data = response.data;
    if (data == null) {
      throw const FormatException('Employees response is empty');
    }
    return data
        .map(
          (item) =>
              TaskEmployee.fromApi(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<TaskboardColumn> renameColumn(
    String columnId,
    RenameTaskColumnRequest request,
  ) async {
    try {
      final response = await apiClient.dio.patch<Map<String, dynamic>>(
        '/task-columns/$columnId',
        data: request.toApi(),
        options: Options(contentType: Headers.jsonContentType),
      );
      if (response.statusCode != 200 || response.data == null) {
        throw const FormatException('Column update response is invalid');
      }
      return TaskboardColumn.fromApi(response.data!);
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    }
  }

  Future<void> archiveColumn(String columnId, {String? moveToColumnId}) async {
    try {
      final response = await apiClient.dio.delete<void>(
        '/task-columns/$columnId',
        queryParameters: {
          if (moveToColumnId != null)
            'move_to_column_id': int.parse(moveToColumnId),
        },
      );
      if (response.statusCode != 204) {
        throw const FormatException('Column archive response is invalid');
      }
    } on DioException catch (error) {
      throw TaskRequestException.fromDio(error);
    }
  }
}
