import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  ApiClient() {
    dio = Dio(
      BaseOptions(
        connectTimeout: Duration(seconds: 5),
        receiveTimeout: Duration(seconds: 10),
        sendTimeout: Duration(seconds: 10),
        baseUrl: "http://127.0.0.1:8000",
        headers: {"Accept": "application/json"},
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (message) => debugPrint(message.toString()),
        ),
      );
    }
  }
  late final Dio dio;
}
