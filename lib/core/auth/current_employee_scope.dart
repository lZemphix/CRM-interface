import 'package:flutter/widgets.dart';

/// Session identity for presentation only. Permissions are enforced by the API.
class CurrentEmployeeScope extends InheritedWidget {
  const CurrentEmployeeScope({
    super.key,
    required this.employeeId,
    required super.child,
  });

  final int? employeeId;

  static int? idOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CurrentEmployeeScope>()
      ?.employeeId;

  @override
  bool updateShouldNotify(CurrentEmployeeScope oldWidget) =>
      oldWidget.employeeId != employeeId;
}
