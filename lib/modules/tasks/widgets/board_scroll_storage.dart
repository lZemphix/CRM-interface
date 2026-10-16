import 'package:flutter/widgets.dart';

/// AppFlowy recreates column scrollables on structural board changes, but does
/// not give them PageStorageKeys or expose their ScrollControllers. Its builders
/// share the column body context; use that context to identify native scroll
/// storage, without depending on the package's private widgets.
class TaskBoardScrollStorage extends PageStorageBucket {
  final _columns = Expando<String>();

  void registerColumn(BuildContext context, String columnId) {
    _columns[context] = columnId;
  }

  Object? _columnIdentifier(BuildContext context) {
    Object? identifier;
    bool visit(BuildContext ancestor) {
      // ExpansionTile and any explicitly keyed child retain normal SDK storage.
      if (ancestor.widget.key is PageStorageKey) return false;
      final columnId = _columns[ancestor];
      if (columnId == null) return true;
      identifier = ('task-column-scroll', columnId);
      return false;
    }

    if (visit(context)) context.visitAncestorElements(visit);
    return identifier;
  }

  @override
  dynamic readState(BuildContext context, {Object? identifier}) => super
      .readState(context, identifier: identifier ?? _columnIdentifier(context));

  @override
  void writeState(BuildContext context, dynamic data, {Object? identifier}) {
    super.writeState(
      context,
      data,
      identifier: identifier ?? _columnIdentifier(context),
    );
  }
}
