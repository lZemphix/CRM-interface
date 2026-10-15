import 'package:crm_interface/core/modules/module_registry.dart';
import 'package:crm_interface/core/auth/current_employee_scope.dart';
import 'package:crm_interface/core/modules/module_data_changes.dart';
import 'package:flutter/material.dart';
import 'package:crm_interface/core/keyboard/search_shortcut_scope.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:crm_interface/layout/sidebar.dart';
import 'package:crm_interface/modules/auth/models/profile.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.modules,
    required this.authRepository,
  });

  final ModuleRegistry modules;
  final AuthRepository authRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _activeModuleId;
  final _pinOverrides = <String, bool>{};
  late Future<AuthProfile> _profile;
  bool _isLoggingOut = false;
  final _dataRevision = ValueNotifier(0);

  @override
  void dispose() {
    _dataRevision.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _activeModuleId = widget.modules.first?.id;
    _profile = widget.authRepository.getProfile();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pinOverrides.removeWhere((id, _) => widget.modules[id] == null);
    if (widget.modules[_activeModuleId]?.screenBuilder == null) {
      _activeModuleId = widget.modules.first?.id;
    }
    if (oldWidget.authRepository != widget.authRepository) {
      _profile = widget.authRepository.getProfile();
    }
  }

  void _reloadProfile() {
    final profile = widget.authRepository.getProfile();
    setState(() {
      _profile = profile;
    });
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    // SessionGate can dispose this screen before the request finishes.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoggingOut = true);
    try {
      await widget.authRepository.logout();
    } on DioException {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Локальный выход выполнен, но серверный выход не подтверждён',
            ),
          ),
        );
      }
    } on PlatformException {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось очистить хранилище входа. Очистите локальные данные приложения',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  void selectModule(String id) {
    if (widget.modules[id]?.screenBuilder == null || _activeModuleId == id) {
      return;
    }
    setState(() {
      _activeModuleId = id;
    });
  }

  void _setModulePinned(String id, bool pinned) {
    if (widget.modules[id] == null || _pinOverrides[id] == pinned) return;
    setState(() => _pinOverrides[id] = pinned);
  }

  Set<String> get _pinnedModuleIds => {
    for (final module in widget.modules.modules)
      if (_pinOverrides[module.id] ?? module.pinnedByDefault) module.id,
  };

  Widget currentScreen(BuildContext moduleContext) {
    final module = widget.modules[_activeModuleId];
    final builder = module?.screenBuilder;
    if (builder == null) {
      return const Center(child: Text('Нет доступных разделов'));
    }
    // Different sections can return the same widget type, but not share State.
    return KeyedSubtree(
      key: ValueKey(module!.id),
      child: builder(moduleContext),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SearchShortcutScope(
        child: NotificationListener<ModuleDataChanged>(
          onNotification: (_) {
            _dataRevision.value++;
            return true;
          },
          child: ModuleDataScope(
            revision: _dataRevision,
            child: FutureBuilder<AuthProfile>(
              future: _profile,
              builder: (context, snapshot) {
                // FutureBuilder may retain old data while a new profile loads.
                final ready =
                    snapshot.connectionState == ConnectionState.done &&
                    !snapshot.hasError &&
                    !_isLoggingOut;
                final profile = ready ? snapshot.data : null;
                return CurrentEmployeeScope(
                  employeeId: profile?.id,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SideBar(
                        modules: widget.modules.modules,
                        activeModuleId: _activeModuleId,
                        onModuleSelected: selectModule,
                        pinnedModuleIds: _pinnedModuleIds,
                        onModulePinChanged: _setModulePinned,
                        accountProfile: profile,
                        accountLoading:
                            snapshot.connectionState != ConnectionState.done,
                        accountError: snapshot.hasError,
                        loggingOut: _isLoggingOut,
                        onReloadProfile: _reloadProfile,
                        onLogout: _logout,
                      ),
                      Expanded(child: Builder(builder: currentScreen)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
