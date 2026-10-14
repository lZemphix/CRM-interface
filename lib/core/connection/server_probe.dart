import 'package:dio/dio.dart';

import '../api_client/endpoint.dart';

class ServerConnectionException implements Exception {
  const ServerConnectionException(this.message);
  final String message;
}

class ServerProbe {
  ServerProbe({Dio Function()? createDio}) : _createDio = createDio ?? Dio.new;

  final Dio Function() _createDio;

  Future<void> check(String url) async {
    final endpoint = ApiEndpoint.validate(url);
    // Separate, short-lived client: no auth interceptor, cookies or tokens.
    final client = _createDio();
    client.options = BaseOptions(
      baseUrl: endpoint,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      followRedirects: false,
      headers: {'Accept': 'application/json'},
    );
    try {
      final response = await client.get<dynamic>('/health');
      final data = response.data;
      if (response.statusCode != 200 ||
          data is! Map ||
          data['status'] != 'ok') {
        throw const ServerConnectionException(
          'По этому адресу сервер не вернул ожидаемый ответ CRM.',
        );
      }
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw ServerConnectionException(
        status == 503
            ? 'Сервер доступен, но пока не готов к работе. Попробуйте позднее.'
            : status != null
            ? 'Сервер ответил HTTP $status. Проверьте адрес. '
                  'Перенаправления не поддерживаются.'
            : 'Не удалось подключиться. Проверьте адрес, сеть и сертификат сервера.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
