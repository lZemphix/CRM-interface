import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/modules/auth/screens/password_change.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crm_interface/core/keyboard/command_scope.dart';
import 'package:crm_interface/core/keyboard/keybindings.dart';
import 'package:crm_interface/core/keyboard/keybindings_dialog.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authRepository,
    required this.onAuthenticated,
    this.serverUrl,
    this.onConfigureServer,
  });

  final AuthRepository authRepository;
  final VoidCallback onAuthenticated;
  final String? serverUrl;
  final Future<void> Function(BuildContext)? onConfigureServer;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _loginFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _needsPasswordChange = false;
  bool _isSubmitting = false;
  bool _configuringServer = false;

  Future<void> _configureServer() async {
    if (_isSubmitting || _configuringServer) return;
    setState(() => _configuringServer = true);
    try {
      await widget.onConfigureServer?.call(context);
    } finally {
      if (mounted) setState(() => _configuringServer = false);
    }
  }

  @override
  void dispose() {
    _loginFocus.dispose();
    _passwordFocus.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting ||
        _configuringServer ||
        !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final mustChangePassword = await widget.authRepository.auth(
        login: _loginController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      _passwordController.clear();

      if (mustChangePassword) {
        setState(() => _needsPasswordChange = true);
      } else {
        _openCrm();
      }
    } on DioException catch (error) {
      if (!mounted) return;
      final message = error.response?.statusCode == 401
          ? 'Неверный логин или пароль'
          : 'Не удалось войти. Проверьте подключение к серверу';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on FormatException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Некорректный ответ сервера')),
      );
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось сохранить сессию в защищённом хранилище. '
            'Проверьте доступ к хранилищу и повторите вход',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openCrm() {
    widget.onAuthenticated();
  }

  Future<void> _returnToLogin() async {
    String? logoutWarning;
    try {
      await widget.authRepository.logout();
    } on DioException {
      logoutWarning =
          'Локальный выход выполнен, но серверный выход не подтверждён: '
          'серверная сессия могла остаться активной';
    }
    if (!mounted) return;
    setState(() => _needsPasswordChange = false);
    if (logoutWarning != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(logoutWarning)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_needsPasswordChange) {
      return ChangeFormScreen(
        authRepository: widget.authRepository,
        onPasswordChanged: _openCrm,
        onReturnToLogin: _returnToLogin,
      );
    }
    return CommandScope(
      commands: {
        AppCommand.submitAuth: () {
          if (_isSubmitting || _configuringServer) return;
          if (_loginFocus.hasFocus) {
            _passwordFocus.requestFocus();
          } else {
            _submit();
          }
        },
        AppCommand.submitForm: _submit,
      },
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 350,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.notActiveBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10,
                  children: [
                    Image.asset(
                      'assets/images/logo.jpg',
                      width: 60,
                      height: 60,
                    ),
                    TextFormField(
                      autofocus: true,
                      focusNode: _loginFocus,
                      textInputAction: TextInputAction.next,
                      enabled: !_isSubmitting && !_configuringServer,
                      controller: _loginController,
                      decoration: const InputDecoration(
                        labelText: 'Логин',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Введите логин'
                          : null,
                    ),
                    TextFormField(
                      focusNode: _passwordFocus,
                      enabled: !_isSubmitting && !_configuringServer,
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Введите пароль'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _isSubmitting || _configuringServer
                            ? null
                            : _submit,
                        child: Text(_isSubmitting ? 'Входим…' : 'Войти'),
                      ),
                    ),
                    if (widget.serverUrl != null)
                      Text(
                        'Сервер: ${widget.serverUrl}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (widget.onConfigureServer != null)
                      TextButton(
                        key: const Key('configure-server'),
                        onPressed: _isSubmitting || _configuringServer
                            ? null
                            : _configureServer,
                        child: const Text('Изменить сервер'),
                      ),
                    if (KeybindingsScope.maybeOf(context) != null)
                      TextButton(
                        key: const Key('login-keybindings'),
                        onPressed: _isSubmitting || _configuringServer
                            ? null
                            : () async {
                                setState(() => _configuringServer = true);
                                try {
                                  await showKeybindingsSettings(context);
                                } finally {
                                  if (mounted) {
                                    setState(() => _configuringServer = false);
                                  }
                                }
                              },
                        child: const Text('Горячие клавиши'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
