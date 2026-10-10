import 'package:flutter/widgets.dart';

/// Public navigation contract; dependencies belong in the module's factory.
class ModuleDefinition {
  const ModuleDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.screenBuilder,
    this.order = 100,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder screenBuilder;
  final int order;
}
