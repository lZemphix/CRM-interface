import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:dio/dio.dart';
import 'package:fresh_dio/fresh_dio.dart';

class AuthRepository {
  const AuthRepository(this.apiClient, this.sessionStore);

  final ApiClient apiClient;
  final SessionStore sessionStore;

  Future<bool> auth({required String login, required String password}) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'login': login, 'password': password},
    );
    final data = response.data;
    if (data == null) throw const FormatException('Пустой ответ сервера');

    final mustChangePassword = data['must_change_password'] as bool;
    await apiClient.fresh.setToken(sessionStore.tokenFromApi(data));
    return mustChangePassword;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    OAuth2Token? token = sessionStore.token;
    if (token == null) {
      throw StateError('Токен отсутствует!');
    }

    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/auth/change-password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
    final data = response.data;
    if (data == null || data['must_change_password'] != false) {
      throw const FormatException('Некорректный ответ сервера');
    }

    await apiClient.fresh.setToken(sessionStore.tokenFromApi(data));
  }

  Future<void> logout() async {
    try {
      await apiClient.dio.post<void>('/auth/logout');
    } on DioException catch (error) {
      // Повторный выход из уже недействительной сессии тоже завершает вход локально.
      if (error.response?.statusCode != 401) rethrow;
    } finally {
      await apiClient.fresh.clearToken();
    }
  }
}
