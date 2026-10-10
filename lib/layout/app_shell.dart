import 'package:crm_interface/core/navigation/app_screen.dart';
import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/customers/screens/customers.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/screens/tasks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:crm_interface/layout/sidebar.dart';
import 'package:crm_interface/modules/auth/models/profile.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.apiClient,
    required this.tasksRepository,
    required this.authRepository,
  });

  final ApiClient apiClient;
  final TasksRepository tasksRepository;
  final AuthRepository authRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppScreen activeScreen = AppScreen.customers;
  late Future<AuthProfile> _profile;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.authRepository.getProfile();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  void selectScreen(AppScreen screen) {
    setState(() {
      activeScreen = screen;
    });
  }

  Widget currentScreen() {
    return switch (activeScreen) {
      AppScreen.customers => CustomersScreen(apiClient: widget.apiClient),
      AppScreen.tasks => TasksScreen(tasksRepository: widget.tasksRepository),
      AppScreen.analytics => const Center(child: Text("analytics")),
      AppScreen.catalog => const Center(child: Text("catalog")),
    };
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
                activeScreen: activeScreen,
                onScreenSelected: selectScreen,
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
