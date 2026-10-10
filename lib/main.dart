import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/layout/app_shell.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/modules/auth/screens/session_gate.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:flutter/material.dart';

void main() {
  final sessionStore = SessionStore();
  final apiClient = ApiClient(sessionStore);
  final authRepository = AuthRepository(apiClient, sessionStore);
  final tasksRepository = TasksRepository(apiClient);

  runApp(
    MyApp(
      authRepository: authRepository,
      apiClient: apiClient,
      tasksRepository: tasksRepository,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.authRepository,
    required this.apiClient,
    required this.tasksRepository,
  });

  final AuthRepository authRepository;
  final ApiClient apiClient;
  final TasksRepository tasksRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CRM',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        canvasColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          // Generated Material surfaces must not tint our shared background.
          surface: AppColors.background,
          surfaceDim: AppColors.background,
          surfaceBright: AppColors.background,
          surfaceContainerLowest: AppColors.background,
          surfaceContainerLow: AppColors.background,
          surfaceContainer: AppColors.background,
          surfaceContainerHigh: AppColors.background,
          surfaceContainerHighest: AppColors.background,
          surfaceTint: Colors.transparent,
        ),
      ),
      home: SessionGate(
        authRepository: authRepository,
        authenticatedBuilder: (context) =>
            AppShell(apiClient: apiClient, tasksRepository: tasksRepository),
      ),
    );
  }
}
