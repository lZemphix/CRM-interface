import 'package:crm_interface/modules/tasks/models/task_column.dart';
import 'package:flutter/material.dart';

import '../repos/request_error.dart';

class CreateTaskColumnWindow extends StatefulWidget {
  const CreateTaskColumnWindow({super.key, required this.onCreate});

  final Future<void> Function(CreateTaskColumnRequest) onCreate;

  @override
  State<CreateTaskColumnWindow> createState() => _CreateTaskColumnWindowState();
}

class _CreateTaskColumnWindowState extends State<CreateTaskColumnWindow> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  TaskColumnStatus? _status;
  bool _isSaving = false;
  String? _saveError;

  Future<void> _submit() async {
    if (_isSaving) return;
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.onCreate(
        CreateTaskColumnRequest(name: _name, status: _status),
      );
      if (mounted) Navigator.of(context).pop();
    } on TaskRequestException catch (error) {
      if (mounted) setState(() => _saveError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saveError = 'Не удалось создать колонку. Попробуйте ещё раз.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        title: const Text('Новая колонка'),
        content: _buildForm(),
        actions: _buildActions(),
      ),
    );
  }

  Widget _buildForm() {
    return SizedBox(
      width: 360,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                autofocus: true,
                enabled: !_isSaving,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Название *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите название колонки'
                    : null,
                onSaved: (value) => _name = value!.trim(),
              ),
              DropdownButtonFormField<TaskColumnStatus>(
                hint: const Text('Без изменения статуса'),
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Статус задач'),
                items: [
                  const DropdownMenuItem<TaskColumnStatus>(
                    child: Text('Без изменения статуса'),
                  ),
                  for (final status in TaskColumnStatus.values)
                    DropdownMenuItem(value: status, child: Text(status.label)),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() => _status = value);
                      },
              ),
              const SizedBox(height: 12),
              const Text(
                'Без статуса колонка только группирует задачи. Новая задача получает статус «Новая». '
                'Выбранный статус применяется при переносе в колонку; изменить эту настройку после создания нельзя.',
              ),
              if (_saveError != null)
                Text(
                  _saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions() {
    return [
      TextButton(
        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _isSaving ? null : _submit,
        child: Text(_isSaving ? 'Создаём…' : 'Создать'),
      ),
    ];
  }
}
