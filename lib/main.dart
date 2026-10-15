import 'package:flutter/widgets.dart';

import 'bootstrap/server_app.dart';
import 'core/keyboard/command_scope.dart';

// Preserve the entry point used by existing widget and integration tests.
export 'app.dart' show MyApp;

void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(KeybindingsHost(child: ServerApp(arguments: arguments)));
}
