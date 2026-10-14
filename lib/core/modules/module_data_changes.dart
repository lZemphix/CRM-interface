import 'package:flutter/widgets.dart';

/// A command may change server data: invalidate readers, not their widget State.
/// Carries no business DTOs; each module decides how to reread its own data.
class ModuleDataChanged extends Notification {
  const ModuleDataChanged();
}

class ModuleDataScope extends InheritedNotifier<ValueNotifier<int>> {
  const ModuleDataScope({
    super.key,
    required ValueNotifier<int> revision,
    required super.child,
  }) : super(notifier: revision);

  static int revisionOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ModuleDataScope>()
          ?.notifier
          ?.value ??
      0;
}
