import 'package:dio/dio.dart';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';

class CustomersRepository {
  const CustomersRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<Customer>> getCustomers({int limit = 50, int offset = 0}) async {
    try {
      final response = await apiClient.dio.get<List<dynamic>>(
        "/customers",
        queryParameters: {"limit": limit, 'offset': offset},
      );

      final jsonList = response.data;

      if (jsonList == null) {
        throw CustomerRequestException("Empty response");
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
}

class CustomerRequestException implements Exception {
  const CustomerRequestException(this.message);

  final String message;

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
        'Сервер вернул ошибку ${error.response?.statusCode}',
      ),

      DioExceptionType.cancel => const CustomerRequestException(
        'Запрос отменён',
      ),

      _ => const CustomerRequestException('Неизвестная сетевая ошибка'),
    };
  }

  @override
  String toString() => message;
}
