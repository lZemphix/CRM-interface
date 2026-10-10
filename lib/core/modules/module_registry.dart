import 'module_definition.dart';

/// Immutable snapshot of registered sections, not a license/access decision.
class ModuleRegistry {
  factory ModuleRegistry(Iterable<ModuleDefinition> definitions) {
    final modules = definitions.toList()
      ..sort((a, b) {
        final order = a.order.compareTo(b.order);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    final byId = <String, ModuleDefinition>{};
    for (final module in modules) {
      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(module.id)) {
        throw ArgumentError.value(module.id, 'id', 'Invalid module identifier');
      }
      if (module.title.trim().isEmpty) {
        throw ArgumentError('Module ${module.id} must have a title');
      }
      if (byId.containsKey(module.id)) {
        throw ArgumentError('Duplicate module identifier: ${module.id}');
      }
      byId[module.id] = module;
    }
    return ModuleRegistry._(List.unmodifiable(modules), Map.unmodifiable(byId));
  }

  const ModuleRegistry._(this.modules, this._byId);

  final List<ModuleDefinition> modules;
  final Map<String, ModuleDefinition> _byId;

  ModuleDefinition? operator [](String? id) => _byId[id];

  ModuleDefinition? get first => modules.isEmpty ? null : modules.first;
}
