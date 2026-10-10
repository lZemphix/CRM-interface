import 'package:crm_interface/core/modules/module_registry.dart';
import 'package:flutter/material.dart';
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
  late Future<AuthProfile> _profile;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _activeModuleId = widget.modules.first?.id;
    _profile = widget.authRepository.getProfile();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.modules[_activeModuleId] == null) {
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
    if (widget.modules[id] == null || _activeModuleId == id) return;
    setState(() {
      _activeModuleId = id;
    });
  }

  Widget currentScreen() {
    final module = widget.modules[_activeModuleId];
    if (module == null) {
      return const Center(child: Text('Нет доступных разделов'));
    }
    // Different sections can return the same widget type, but not share State.
    return KeyedSubtree(
      key: ValueKey(module.id),
      child: module.screenBuilder(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          FutureBuilder<AuthProfile>(
            future: _profile,
            builder: (context, snapshot) {
              final profile = snapshot.hasError ? null : snapshot.data;
              return SideBar(
                modules: widget.modules.modules,
                activeModuleId: _activeModuleId,
                onModuleSelected: selectModule,
                accountProfile: profile,
                accountLoading:
                    snapshot.connectionState != ConnectionState.done,
                accountError: snapshot.hasError,
                loggingOut: _isLoggingOut,
                onReloadProfile: _reloadProfile,
                onLogout: _logout,
              );
            },
          ),
          Expanded(child: currentScreen()),
        ],
      ),
    );
  }
}
