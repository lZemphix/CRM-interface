import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/modules/auth/screens/password_change.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authRepository,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _needsPasswordChange = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

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
    return Scaffold(
      body: Center(
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
                Image.asset('assets/images/logo.jpg', width: 60, height: 60),
                TextFormField(
                  controller: _loginController,
                  decoration: const InputDecoration(
                    labelText: 'Логин',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Введите логин'
                      : null,
                ),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Введите пароль' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(_isSubmitting ? 'Входим…' : 'Войти'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
