import 'package:flutter/widgets.dart';

import 'bootstrap/server_app.dart';

// Preserve the entry point used by existing widget and integration tests.
export 'app.dart' show MyApp;

void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ServerApp(arguments: arguments));
}
