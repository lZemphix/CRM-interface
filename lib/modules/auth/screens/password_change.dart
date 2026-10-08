import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class ChangeFormScreen extends StatefulWidget {
  const ChangeFormScreen({
    super.key,
    required this.authRepository,
    required this.onPasswordChanged,
    required this.onReturnToLogin,
  });

  final AuthRepository authRepository;
  final VoidCallback onPasswordChanged;
  final VoidCallback onReturnToLogin;

  @override
  State<ChangeFormScreen> createState() => _ChangeFormScreenState();
}

class _ChangeFormScreenState extends State<ChangeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.authRepository.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      widget.onPasswordChanged();
    } on DioException catch (error) {
      if (!mounted) return;
      final message = switch (error.response?.statusCode) {
        400 => 'Неверный текущий пароль',
        401 => 'Сессия истекла. Вернитесь ко входу',
        422 => 'Новый пароль не прошёл проверку сервера',
        _ => 'Не удалось сменить пароль. Проверьте подключение',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on FormatException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Некорректный ответ сервера')),
      );
    } on StateError catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия не найдена. Вернитесь ко входу')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Center(
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
                    const Text('Смена временного пароля'),
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Текущий пароль',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Введите текущий пароль'
                          : null,
                    ),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Новый пароль',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 15 || value.length > 128) {
                          return 'От 15 до 128 символов';
                        }
                        if (value == _currentPasswordController.text) {
                          return 'Новый пароль должен отличаться от текущего';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Повторите новый пароль',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == _newPasswordController.text
                          ? null
                          : 'Пароли не совпадают',
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: Text(_isSubmitting ? 'Сохраняем…' : 'Сменить пароль'),
                        ),
                        TextButton(
                          onPressed: _isSubmitting ? null : widget.onReturnToLogin,
                          child: const Text('Назад'),
                        ),
                      ],
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
