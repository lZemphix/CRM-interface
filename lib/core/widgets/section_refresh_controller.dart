import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// UI-only contract: several blocks can participate in one section refresh.
class SectionRefreshController extends ChangeNotifier {
  final _participants =
      <Object, ({AsyncCallback refresh, bool Function() busy})>{};
  bool _running = false;
  bool _disposed = false;
  bool _notificationPending = false;

  bool get isBusy =>
      _running || _participants.values.any((entry) => entry.busy());
  bool get canRefresh => _participants.isNotEmpty && !isBusy;

  void attach(
    Object owner, {
    required AsyncCallback refresh,
    required bool Function() busy,
  }) {
    _participants[owner] = (refresh: refresh, busy: busy);
    changed();
  }

  void detach(Object owner) {
    _participants.remove(owner);
    changed();
  }

  void changed() {
    if (_disposed) return;
    // A child may register/start loading while its parent is building.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notificationPending) return;
      _notificationPending = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notificationPending = false;
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (!canRefresh || _disposed) return;
    final callbacks = _participants.values
        .map((entry) => entry.refresh)
        .toList();
    _running = true;
    changed();
    try {
      await Future.wait(callbacks.map((callback) => callback()));
    } finally {
      _running = false;
      changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _participants.clear();
    super.dispose();
  }
}
