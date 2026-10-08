import 'package:dio/dio.dart';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:crm_interface/modules/customers/models/create_customer.dart';
import 'package:crm_interface/modules/customers/models/customer_note.dart';

import '../models/customer_activity.dart';

class CustomersRepository {
  const CustomersRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<CustomerFormOption>> getBranches() => _getOptions('/branches');

  Future<CustomerActivityPage> getActivity(
    int customerId, {
    int limit = 20,
    int offset = 0,
    CustomerActivityType? type,
  }) async {
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        '/customers/$customerId/activity',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (type != null) 'type': type.apiValue,
        },
      );
      if (response.data == null) throw const FormatException('Empty activity');
      return CustomerActivityPage.fromApi(response.data!);
    } on DioException catch (error) {
      throw CustomerRequestException.fromDio(error);
    } on FormatException {
      throw const CustomerRequestException('Некорректная лента активности');
    } on TypeError {
      throw const CustomerRequestException('Некорректная лента активности');
    }
  }

  // The API lists active notes as part of customer details, not a separate GET.
  Future<List<CustomerNote>> getCustomerNotes(int customerId) async {
    try {
      return (await getCustomerDetails(id: customerId)).notes;
    } on FormatException {
      throw const CustomerRequestException('Некорректный список заметок');
    } on TypeError {
      throw const CustomerRequestException('Некорректный список заметок');
    }
  }

  Future<CustomerNote> createNote(
    int customerId,
    CreateCustomerNoteRequest request,
  ) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        '/customers/$customerId/notes',
        data: request.toApi(),
      );
      return _noteFromResponse(response, expectedStatus: 201);
    } on DioException catch (error) {
      throw _noteMutationError(error);
    }
  }

  Future<CustomerNote> updateNote(
    int customerId,
    int noteId,
    UpdateCustomerNoteRequest request,
  ) async {
    try {
      final response = await apiClient.dio.patch<Map<String, dynamic>>(
        '/customers/$customerId/notes/$noteId',
        data: request.toApi(),
      );
      return _noteFromResponse(response, expectedStatus: 200);
    } on DioException catch (error) {
      throw _noteMutationError(error);
    }
  }

  Future<void> archiveNote(int customerId, int noteId) async {
    try {
      final response = await apiClient.dio.delete<void>(
        '/customers/$customerId/notes/$noteId',
      );
      if (response.statusCode != 204) {
        throw const CustomerRequestException(
          'Архивирование не подтверждено. Обновите список заметок.',
          refreshRequired: true,
        );
      }
    } on DioException catch (error) {
      throw _noteMutationError(error);
    }
  }

  CustomerNote _noteFromResponse(
    Response<Map<String, dynamic>> response, {
    required int expectedStatus,
  }) {
    try {
      if (response.statusCode != expectedStatus || response.data == null) {
        throw const FormatException('Invalid note response');
      }
      return CustomerNote.fromJson(response.data!);
    } on FormatException {
      throw const CustomerRequestException(
        'Сохранение не подтверждено. Закройте форму и обновите список заметок.',
        refreshRequired: true,
      );
    } on TypeError {
      throw const CustomerRequestException(
        'Сохранение не подтверждено. Закройте форму и обновите список заметок.',
        refreshRequired: true,
      );
    }
  }

  CustomerRequestException _noteMutationError(DioException error) {
    final safe = CustomerRequestException.fromDio(error);
    final status = error.response?.statusCode;
    // A conflict needs fresh version; a timeout/5xx may follow a committed POST.
    return CustomerRequestException(
      safe.message,
      refreshRequired:
          status == null || status == 404 || status == 409 || status >= 500,
    );
  }

  Future<CreatedCustomerResponse> createCustomer(
    CreateCustomerRequest request,
  ) async {
    try {
      final response = await apiClient.dio.post<Map<String, dynamic>>(
        '/customers',
        data: request.toApi(),
      );
      final json = response.data;
      if (json == null) {
        throw const CustomerRequestException(
          'Сервер не вернул результат. Проверьте список перед повторным созданием.',
        );
      }
      try {
        return CreatedCustomerResponse.fromJson(json);
      } on FormatException {
        throw const CustomerRequestException(
          'Некорректный результат сервера. Проверьте список перед повторным созданием.',
        );
      } on TypeError {
        throw const CustomerRequestException(
          'Неполный результат сервера. Проверьте список перед повторным созданием.',
        );
      }
    } on DioException catch (error) {
      throw CustomerRequestException.fromDio(error);
    }
  }

  Future<CustomerCreationOptions> getCreationOptions() async {
    final lists = await Future.wait([
      _getOptions('/acquisition-sources'),
      _getOptions('/branches'),
      _getOptions('/employees', nameKey: 'full_name'),
    ]);
    return CustomerCreationOptions(
      sources: lists[0],
      branches: lists[1],
      employees: lists[2],
    );
  }

  Future<List<CustomerFormOption>> _getOptions(
    String path, {
    String nameKey = 'name',
  }) async {
    try {
      final response = await apiClient.dio.get<List<dynamic>>(path);
      final items = response.data;
      if (items == null) {
        throw const CustomerRequestException('Сервер не вернул справочник');
      }
      return items.map((item) {
        if (item is! Map || item['id'] is! int || item[nameKey] is! String) {
          throw const CustomerRequestException('Некорректный справочник');
        }
        return CustomerFormOption(
          id: item['id'] as int,
          name: item[nameKey] as String,
        );
      }).toList();
    } on DioException catch (error) {
      throw CustomerRequestException.fromDio(error);
    }
  }

  Future<List<Customer>> getCustomers({
    int limit = 50,
    int offset = 0,
    String? search,
  }) async {
    final query = search?.trim();
    try {
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        "/customers",
        queryParameters: {
          "limit": limit,
          'offset': offset,
          if (query != null && query.isNotEmpty) 'search': query,
        },
      );

      final jsonList = response.data?['items'];

      if (jsonList is! List) {
        throw const CustomerRequestException("Некорректный список клиентов");
      }

      return jsonList
          .map(
            (json) => Customer.fromJson(Map<String, dynamic>.from(json as Map)),
          )
          .toList();
    } on DioException catch (error) {
      throw CustomerRequestException.fromDio(error);
    }
  }

  Future<CustomerDetails> getCustomerDetails({required int id}) async {
    try {
      final response = await apiClient.dio.get("/customers/$id");
      final json = response.data;

      if (json == null) {
        throw const CustomerRequestException("Empty response");
      }

      return CustomerDetails.fromJson(json);
    } on DioException catch (error) {
      throw CustomerRequestException.fromDio(error);
    }
  }
}

class CustomerRequestException implements Exception {
  const CustomerRequestException(this.message, {this.refreshRequired = false});

  final String message;
  final bool refreshRequired;

  factory CustomerRequestException.fromDio(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout => const CustomerRequestException(
        'Не удалось подключиться к серверу',
      ),

      DioExceptionType.receiveTimeout => const CustomerRequestException(
        'Сервер слишком долго отвечает',
      ),

      DioExceptionType.connectionError => const CustomerRequestException(
        'Сервер недоступен',
      ),

      DioExceptionType.badResponse => CustomerRequestException(
        _responseMessage(error.response),
      ),

      DioExceptionType.cancel => const CustomerRequestException(
        'Запрос отменён',
      ),

      _ => const CustomerRequestException('Неизвестная сетевая ошибка'),
    };
  }

  static String _responseMessage(Response<dynamic>? response) {
    final status = response?.statusCode;
    if (status == 401) return 'Сессия завершена. Войдите снова.';
    if (status == 403) return 'Недостаточно прав для этого действия';
    if (status != null && status >= 500) {
      return 'Ошибка сервера. Попробуйте позже.';
    }
    final data = response?.data;
    final detail = data is Map ? data['detail'] : null;
    if (detail is Map && detail['message'] is String) {
      final errors = detail['errors'];
      if (errors is List) {
        final messages = [
          for (final error in errors.take(5))
            if (error is Map && error['message'] is String)
              error['message'] as String,
        ];
        if (messages.isNotEmpty) return messages.join('\n');
      }
      return detail['message'] as String;
    }
    if (status == 422) return 'Проверьте заполненные поля';
    return 'Сервер вернул ошибку $status';
  }

  @override
  String toString() => message;
}
