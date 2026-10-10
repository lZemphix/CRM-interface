// GENERATED CODE - DO NOT MODIFY BY HAND.
// Run: dart run tool/generate_modules.dart

import '../core/api_client/client.dart';
import '../core/modules/module_registry.dart';
import '../modules/analytics/module.dart' as module0;
import '../modules/catalog/module.dart' as module1;
import '../modules/customers/module.dart' as module2;
import '../modules/tasks/module.dart' as module3;

ModuleRegistry createModuleRegistry(ApiClient apiClient) {
  return ModuleRegistry([
    module0.createModule(apiClient),
    module1.createModule(apiClient),
    module2.createModule(apiClient),
    module3.createModule(apiClient),
  ]);
}
