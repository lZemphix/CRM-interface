import '../core/api_client/client.dart';
import '../core/modules/module_registry.dart';
import '../modules/auth/auth_session.dart';
import '../modules/auth/repos/auth.dart';
import 'modules.g.dart';

/// A dependency graph belongs to exactly one server and one local session.
class AppRuntime {
  factory AppRuntime(String url) {
    final session = SessionStore(serverUrl: url);
    final client = ApiClient(session, baseUrl: url);
    return AppRuntime.withDependencies(
      url: url,
      client: client,
      auth: AuthRepository(client, session),
      modules: createModuleRegistry(client),
    );
  }

  AppRuntime.withDependencies({
    required this.url,
    required this.client,
    required this.auth,
    required this.modules,
  });

  final String url;
  final ApiClient client;
  final AuthRepository auth;
  final ModuleRegistry modules;
  bool retired = false;

  Future<void> retire() async {
    retired = true;
    client.cancelRequests();
    await client.sessionStore.retire();
    await client.sessionStore.clearLegacyToken();
    await client.fresh.clearToken();
  }

  Future<void> close() => client.close();
}
