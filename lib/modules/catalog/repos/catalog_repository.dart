import 'package:crm_interface/core/api_client/client.dart';
import 'package:dio/dio.dart';

import '../models/catalog_input.dart';
import '../models/catalog_item.dart';

class CatalogRequestException implements Exception {
  const CatalogRequestException(
    this.message, {
    this.uncertain = false,
    this.conflict = false,
  });

  final String message;
  final bool uncertain;
  final bool conflict;

  factory CatalogRequestException.fromDio(
    DioException error, {
    bool mutation = false,
  }) {
    final status = error.response?.statusCode;
    if (status == 401) {
      return const CatalogRequestException('Сессия завершена. Войдите снова.');
    }
    if (status == 403) {
      return const CatalogRequestException(
        'Недостаточно прав для работы с каталогом.',
      );
    }
    final detail = error.response?.data;
    final body = detail is Map ? detail['detail'] : null;
    if (status != null && status >= 400 && status < 500) {
      final versionConflict = body is Map && body['code'] == 'version_conflict';
      return CatalogRequestException(
        versionConflict
            ? 'Позицию уже изменили. Скопируйте нужный текст и откройте форму заново.'
            : body is Map && body['message'] is String
            ? body['message'] as String
            : status == 404
            ? 'Позиция не найдена. Обновите каталог.'
            : 'Проверьте данные позиции и попробуйте ещё раз.',
        conflict: versionConflict,
      );
    }
    return CatalogRequestException(
      mutation
          ? 'Сервер не подтвердил изменение. Не повторяйте действие вслепую: проверьте обновлённый каталог.'
          : 'Не удалось загрузить каталог. Проверьте соединение и повторите запрос.',
      uncertain: mutation,
    );
  }

  @override
  String toString() => message;
}

class CatalogRepository {
  const CatalogRepository(this.apiClient);

  final ApiClient apiClient;

  Future<T> _object<T>(
    Future<Response<Map<String, dynamic>>> Function() request,
    T Function(Map<String, dynamic>) decode, {
    int status = 200,
    bool mutation = false,
  }) async {
    try {
      final response = await request();
      if (response.statusCode != status || response.data == null) {
        throw const FormatException('Invalid catalog response');
      }
      return decode(response.data!);
    } on DioException catch (error) {
      throw CatalogRequestException.fromDio(error, mutation: mutation);
    } on FormatException {
      throw CatalogRequestException(
        'Некорректный ответ каталога. Обновите данные.',
        uncertain: mutation,
      );
    } on TypeError {
      throw CatalogRequestException(
        'Некорректный ответ каталога. Обновите данные.',
        uncertain: mutation,
      );
    }
  }

  Future<CatalogPage> getItems({
    String search = '',
    CatalogKind? kind,
    String? category,
    int offset = 0,
  }) => _object(
    () => apiClient.dio.get<Map<String, dynamic>>(
      '/catalog/items',
      queryParameters: {
        'limit': 50,
        'offset': offset,
        'sort': 'name',
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (kind != null) 'kind': kind.apiValue,
        'category': ?category,
      },
    ),
    CatalogPage.fromApi,
  );

  Future<List<String>> getCategories() async {
    try {
      final response = await apiClient.dio.get<List<dynamic>>(
        '/catalog/categories',
      );
      if (response.data == null) {
        throw const FormatException('Empty categories');
      }
      return List.unmodifiable(response.data!.map((value) => value as String));
    } on DioException catch (error) {
      throw CatalogRequestException.fromDio(error);
    } on FormatException {
      throw const CatalogRequestException('Некорректный список категорий.');
    } on TypeError {
      throw const CatalogRequestException('Некорректный список категорий.');
    }
  }

  Future<CatalogItemDetails> getItem(int id) => _object(
    () => apiClient.dio.get<Map<String, dynamic>>('/catalog/items/$id'),
    CatalogItemDetails.fromApi,
  );

  Future<CatalogItemDetails> createItem(CatalogItemInput input) => _object(
    () => apiClient.dio.post<Map<String, dynamic>>(
      '/catalog/items',
      data: input.toCreateApi(),
    ),
    CatalogItemDetails.fromApi,
    status: 201,
    mutation: true,
  );

  Future<CatalogItemDetails> updateItem(
    int id,
    CatalogItemInput input,
    int version,
  ) => _object(
    () => apiClient.dio.patch<Map<String, dynamic>>(
      '/catalog/items/$id',
      data: input.toUpdateApi(version),
    ),
    CatalogItemDetails.fromApi,
    mutation: true,
  );

  Future<void> archiveItem(int id) async {
    try {
      final response = await apiClient.dio.delete<void>('/catalog/items/$id');
      if (response.statusCode != 204) {
        throw const CatalogRequestException(
          'Архивирование не подтверждено. Обновите каталог.',
          uncertain: true,
        );
      }
    } on DioException catch (error) {
      throw CatalogRequestException.fromDio(error, mutation: true);
    }
  }
}
