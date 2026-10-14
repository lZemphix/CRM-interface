import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:fresh_dio/fresh_dio.dart';

import 'endpoint.dart';

class ApiClient {
  ApiClient(this.sessionStore, {String baseUrl = ApiEndpoint.defaultUrl}) {
    final endpoint = ApiEndpoint.validate(baseUrl);
    dio = Dio(
      BaseOptions(
        connectTimeout: Duration(seconds: 5),
        receiveTimeout: Duration(seconds: 10),
        sendTimeout: Duration(seconds: 10),
        baseUrl: endpoint,
        followRedirects: false,
        headers: {"Accept": "application/json"},
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          responseHeader: false,
          requestBody: false,
          responseBody: false,
          logPrint: (message) => debugPrint(message.toString()),
        ),
      );
    }
    _refreshDio = Dio(
      BaseOptions(
        connectTimeout: Duration(seconds: 5),
        receiveTimeout: Duration(seconds: 10),
        sendTimeout: Duration(seconds: 10),
        baseUrl: endpoint,
        followRedirects: false,
        headers: {"Accept": "application/json"},
      ),
    );

    fresh = Fresh.oAuth2<OAuth2Token>(
      tokenStorage: sessionStore,
      httpClient: _refreshDio,

      // На запрос входа access-токен добавлять не нужно.
      isTokenRequired: (options) => options.path != '/auth/login',

      // Эту функцию Fresh вызовет, когда понадобится обновить токены.
      refreshToken: (oldToken, client) async {
        final refresh = oldToken?.refreshToken;
        if (refresh == null) throw RevokeTokenException();

        try {
          final response = await client.post<Map<String, dynamic>>(
            '/auth/refresh',
            data: {'refresh_token': refresh},
          );
          return sessionStore.tokenFromApi(response.data!);
        } on DioException catch (error) {
          if (error.response?.statusCode == 401) {
            throw RevokeTokenException();
          }
          rethrow;
        }
      },
    );
    dio.interceptors.add(fresh);
  }
  late final Dio dio;
  late final Fresh<OAuth2Token> fresh;
  late final Dio _refreshDio;
  final SessionStore sessionStore;

  void cancelRequests() {
    dio.close(force: true);
    _refreshDio.close(force: true);
  }

  Future<void> close() async {
    cancelRequests();
    await fresh.close();
  }
}
