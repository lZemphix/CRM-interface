/// One endpoint for both API requests and refresh-token rotation.
class ApiEndpoint {
  static const defaultUrl = String.fromEnvironment(
    'CRM_API_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static String fromArguments(List<String> arguments) {
    final overrides = arguments.where((arg) => arg.startsWith('--api-url='));
    if (overrides.length > 1) {
      throw const FormatException('Укажите --api-url только один раз');
    }
    return validate(
      overrides.isEmpty ? defaultUrl : overrides.single.substring(10),
    );
  }

  static String validate(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw const FormatException(
        'Адрес API должен быть http://host:port или https://host '
        'без логина, пароля, параметров и фрагмента',
      );
    }
    return uri.toString().replaceFirst(RegExp(r'/+$'), '');
  }
}
