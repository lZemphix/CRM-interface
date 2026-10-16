import 'dart:async';

import 'package:flutter/material.dart';

import 'core/modules/module_registry.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/theme_settings.dart';
import 'layout/app_shell.dart';
import 'modules/auth/repos/auth.dart';
import 'modules/auth/screens/session_gate.dart';

class CrmAppFrame extends StatefulWidget {
  const CrmAppFrame({super.key, required this.home, this.themeController});
  final Widget home;
  final ThemeController? themeController;
  @override
  State<CrmAppFrame> createState() => _CrmAppFrameState();
}

class _CrmAppFrameState extends State<CrmAppFrame> {
  late ThemeController _controller;
  late bool _ownsController;
  @override
  void initState() {
    super.initState();
    _ownsController = widget.themeController == null;
    _controller = widget.themeController ?? ThemeController();
    unawaited(_controller.load());
  }

  @override
  void didUpdateWidget(covariant CrmAppFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeController != widget.themeController) {
      if (_ownsController) _controller.dispose();
      _ownsController = widget.themeController == null;
      _controller = widget.themeController ?? ThemeController();
      unawaited(_controller.load());
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    child: widget.home,
    builder: (_, child) => !_controller.loaded
        ? ColoredBox(color: AppPalette.light.background)
        : ThemeSettingsScope(
            controller: _controller,
            child: MaterialApp(
              title: 'CRM',
              theme: buildAppTheme(Brightness.light),
              darkTheme: buildAppTheme(Brightness.dark),
              themeMode: _controller.mode,
              // The first content frame already uses the persisted palette.
              home: child,
            ),
          ),
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
