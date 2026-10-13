import 'package:flutter/widgets.dart';

/// Public navigation contract; dependencies belong in the module's factory.
class ModuleDefinition {
  const ModuleDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required WidgetBuilder this.screenBuilder,
    this.order = 100,
    this.pinnedByDefault = true,
  }) : actions = const [];

  ModuleDefinition.menu({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required Iterable<ModuleAction> actions,
    this.order = 100,
    this.pinnedByDefault = false,
  }) : screenBuilder = null,
       actions = List.unmodifiable(actions);

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder? screenBuilder;
  final List<ModuleAction> actions;
  final int order;
  // Navigation placement only; never an access or license flag.
  final bool pinnedByDefault;
}

class ModuleAction {
  const ModuleAction({
    required this.id,
    required this.title,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });

  final String id;
  final String title;
  final IconData icon;
  final Future<void> Function(BuildContext) onSelected;
  final bool destructive;
}
