import 'package:flutter/material.dart';

import 'core/modules/module_registry.dart';
import 'core/theme/light/colorscheme.dart';
import 'layout/app_shell.dart';
import 'modules/auth/repos/auth.dart';
import 'modules/auth/screens/session_gate.dart';

class CrmAppFrame extends StatelessWidget {
  const CrmAppFrame({super.key, required this.home});
  final Widget home;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CRM',
    theme: ThemeData(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
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
    home: home,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.authRepository,
    required this.modules,
    this.serverUrl,
    this.onConfigureServer,
  });
  final AuthRepository authRepository;
  final ModuleRegistry modules;
  final String? serverUrl;
  final Future<void> Function(BuildContext)? onConfigureServer;
  @override
  Widget build(BuildContext context) => CrmAppFrame(
    home: SessionGate(
      authRepository: authRepository,
      serverUrl: serverUrl,
      onConfigureServer: onConfigureServer,
      authenticatedBuilder: (context) =>
          AppShell(modules: modules, authRepository: authRepository),
    ),
  );
}
