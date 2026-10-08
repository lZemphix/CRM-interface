import 'package:flutter/material.dart';

import '../models/taskboard.dart';
import '../repos/request_error.dart';
import 'task_column_header.dart';

class TaskColumnActionWindow extends StatefulWidget {
  const TaskColumnActionWindow({
    super.key,
    required this.column,
    required this.action,
    required this.targets,
    required this.onRename,
    required this.onArchive,
    this.lastStatusColumn = false,
    this.canArchiveWithoutTarget = false,
  });

  final TaskboardColumn column;
  final TaskColumnAction action;
  final List<TaskboardColumn> targets;
  final Future<void> Function(String name) onRename;
  final Future<void> Function(String? targetId) onArchive;
  final bool lastStatusColumn;
  final bool canArchiveWithoutTarget;

  @override
  State<TaskColumnActionWindow> createState() => _TaskColumnActionWindowState();
}

class _TaskColumnActionWindowState extends State<TaskColumnActionWindow> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  String? _target;
  bool _saving = false;
  String? _error;

  bool get _isRename => widget.action == TaskColumnAction.rename;
  bool get _canArchive =>
      !widget.lastStatusColumn &&
      (widget.canArchiveWithoutTarget || widget.targets.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _name = widget.column.name;
    _target = widget.canArchiveWithoutTarget
        ? null
        : widget.targets.firstOrNull?.id;
  }

  Future<void> _submit() async {
    if (_saving || (!_isRename && !_canArchive)) return;
    if (_isRename) {
      if (!_formKey.currentState!.validate()) return;
      _formKey.currentState!.save();
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isRename) {
        await widget.onRename(_name);
      } else {
        await widget.onArchive(_target);
      }
      if (mounted) Navigator.of(context).pop();
    } on TaskRequestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось сохранить изменения. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          _isRename ? 'Переименовать колонку' : 'Архивировать колонку',
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isRename) _nameField() else _archiveFields(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: _saving || (!_isRename && !_canArchive) ? null : _submit,
            child: Text(
              _saving
                  ? 'Сохраняем…'
                  : _isRename
                  ? 'Сохранить'
                  : 'Архивировать',
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameField() {
    return Form(
      key: _formKey,
      child: TextFormField(
        initialValue: _name,
        autofocus: true,
        enabled: !_saving,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'Название *'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Введите название колонки'
            : null,
        onSaved: (value) => _name = value!.trim(),
      ),
    );
  }

  Widget _archiveFields() {
    if (widget.lastStatusColumn) {
      return const Text(
        'Это последняя колонка своего статуса. Сначала создайте другую колонку с таким же статусом.',
      );
    }
    if (widget.canArchiveWithoutTarget) {
      return const Text(
        'Колонка исчезнет с доски. Если в ней появились задачи, сервер отклонит архивирование — сначала обновите доску.',
      );
    }
    if (widget.targets.isEmpty) {
      return const Text(
        'Нет подходящей колонки для переноса задач. Создайте колонку без статуса и повторите попытку.',
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('«${widget.column.name}» исчезнет с доски. Задачи не удаляются.'),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _target,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Перенести задачи в'),
          items: [
            for (final column in widget.targets)
              DropdownMenuItem(
                value: column.id,
                child: Text(column.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _saving
              ? null
              : (value) => setState(() => _target = value),
        ),
        const SizedBox(height: 12),
        const Text(
          'Статусы задач сохраняются. Для разных статусов выбирайте колонку без статуса; совместимость проверит сервер.',
        ),
      ],
    );
  }
}
