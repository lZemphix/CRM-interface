import 'package:flutter/material.dart';

import 'package:crm_interface/core/keyboard/dialog_keyboard_scope.dart';
import 'package:crm_interface/core/theme/app_palette.dart';

import '../models/task_details.dart';
import '../models/taskboard.dart';
import '../models/tasks.dart';
import '../repos/request_error.dart';
import '../repos/tasks.dart';
import 'task_actions.dart';
import 'task_card.dart';
import 'task_details_content.dart';
import 'task_history.dart';

class TaskDetailsWindow extends StatefulWidget {
  const TaskDetailsWindow({
    super.key,
    required this.task,
    required this.repository,
    required this.onChanged,
  });

  final TaskboardTask task;
  final TasksRepository repository;
  final Future<void> Function(TaskboardTask) onChanged;

  @override
  State<TaskDetailsWindow> createState() => _TaskDetailsWindowState();
}

class _TaskDetailsWindowState extends State<TaskDetailsWindow> {
  final _keyboard = GlobalKey<DialogKeyboardScopeState>();
  final _descriptionForm = GlobalKey<FormState>();
  final _description = TextEditingController();
  late TaskboardTask _task;
  TaskDetails? _details;
  bool _loading = false;
  bool _saving = false;
  bool _openingAction = false;
  bool _editingDescription = false;
  bool _needsRefresh = false;
  String? _error;
  int _requestId = 0;

  bool get _busy => _loading || _saving || _openingAction;
  bool get _closed => const {'confirmed', 'cancelled'}.contains(_task.status);
  bool get _canEdit => !_busy && !_needsRefresh && !_closed && _details != null;
  bool get _descriptionDirty =>
      _editingDescription && _description.text != (_task.description ?? '');

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await widget.repository.getTaskDetails(widget.task.id);
      if (!mounted || requestId != _requestId) return;
      if (details.task.id != _task.id || details.task.version < _task.version) {
        throw const TaskRequestException(
          'Сервер вернул устаревшие данные. Обновите карточку ещё раз.',
        );
      }
      setState(() {
        _details = details;
        _task = details.task;
        _needsRefresh = false;
      });
      await widget.onChanged(details.task);
    } on TaskRequestException catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _error = error.message;
          _needsRefresh = true;
        });
      }
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _error = 'Не удалось обновить карточку. Попробуйте ещё раз.';
          _needsRefresh = true;
        });
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _accept(TaskboardTask updated) async {
    if (!mounted) return;
    if (updated.id != _task.id || updated.version < _task.version) {
      throw const FormatException('Invalid updated task');
    }
    _requestId++;
    setState(() {
      _task = updated;
      _editingDescription = false;
    });
    // Publish the confirmed DTO before the follow-up GET, including if it fails.
    await widget.onChanged(updated);
    if (mounted) await _load();
  }

  Future<void> _saveDescription() async {
    if (!_canEdit || !_descriptionForm.currentState!.validate()) return;
    final value = _description.text.trim();
    if (value == (_task.description ?? '')) {
      setState(() => _editingDescription = false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.updateDescription(
        _task.id,
        UpdateTaskDescriptionRequest(
          description: value.isEmpty ? null : value,
          version: _task.version,
        ),
      );
      await _accept(updated);
    } on TaskRequestException catch (error) {
      _mutationFailed(error.message);
    } catch (_) {
      _mutationFailed('Не удалось подтвердить сохранение. Обновите карточку.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _mutationFailed(String message) {
    if (!mounted) return;
    setState(() {
      _error = '$message Перед повторным изменением обновите карточку.';
      _needsRefresh = true;
    });
  }

  Future<bool> _cancelDescription() async {
    if (_descriptionDirty) {
      final discard = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => DialogKeyboardScope(
          onClose: () => Navigator.of(context).pop(false),
          child: AlertDialog(
            title: const Text('Отменить изменения?'),
            content: const Text('Описание не будет сохранено.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Продолжить редактирование'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Не сохранять'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || discard != true) return false;
    }
    if (mounted) setState(() => _editingDescription = false);
    return true;
  }

  Future<void> _refresh() async {
    if (_busy || !await _cancelDescription() || !mounted) return;
    await _load();
  }

  Future<void> _markSubtask(TaskboardTaskSubtask subtask, bool done) async {
    if (!_canEdit || _editingDescription) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.markSubtask(
        _task.id,
        subtask.id,
        MarkSubtaskRequest(done: done, version: _task.version),
      );
      await _accept(updated);
    } on TaskRequestException catch (error) {
      _mutationFailed(error.message);
    } catch (_) {
      _mutationFailed('Не удалось подтвердить изменение подзадачи.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openAction(TaskCardAction action) async {
    if (_busy) return;
    if (action != TaskCardAction.history &&
        (!_canEdit || !await _cancelDescription() || !mounted)) {
      return;
    }
    setState(() => _openingAction = true);
    try {
      if (action == TaskCardAction.history) {
        await showDialog<void>(
          context: context,
          builder: (_) => TaskHistoryWindow(
            taskId: _task.id,
            repository: widget.repository,
          ),
        );
        return;
      }
      // An open modal can outlive other employees' edits. Refresh before a form.
      await _load();
      if (!mounted || _needsRefresh || _closed) return;
      var employees = <TaskEmployee>[];
      var assignmentEnabled = true;
      if (const {'new', 'in_progress', 'rework'}.contains(_task.status)) {
        try {
          employees = await widget.repository.getEmployees();
        } on TaskRequestException {
          // Reading employees must not become a prerequisite for editing text.
          assignmentEnabled = false;
        }
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TaskActionWindow(
          task: _task,
          action: action,
          employees: employees,
          includeAssignment: true,
          assignmentEnabled: assignmentEnabled,
          onReload: () async {
            await _load();
            if (_needsRefresh) {
              throw TaskRequestException(_error ?? 'Обновите карточку задачи.');
            }
            return _task;
          },
          searchCustomers: widget.repository.searchCustomers,
          onEdit: (request) async {
            final updated = await widget.repository.editTask(_task.id, request);
            await _accept(updated);
            return updated;
          },
          onAssign: (request) async {
            if (_needsRefresh) {
              throw const TaskRequestException(
                'Сначала обновите состояние задачи.',
              );
            }
            final updated = await widget.repository.assignTask(
              _task.id,
              request,
            );
            await _accept(updated);
            return updated;
          },
        ),
      );
    } on TaskRequestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось открыть форму. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) => DialogKeyboardScope(
    key: _keyboard,
    busy: _saving || _openingAction,
    hasChanges: () => _descriptionDirty,
    onSubmit: _editingDescription ? _saveDescription : null,
    child: Dialog(
      backgroundColor: context.colors.taskCardBackground,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 940,
        height: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaskDetailsHeader(
              task: _task,
              columnName: _details?.columnName,
              onRefresh: _busy ? null : _refresh,
              onHistory: _busy
                  ? null
                  : () => _openAction(TaskCardAction.history),
              onClose: _saving || _openingAction
                  ? null
                  : () => _keyboard.currentState?.requestClose(),
            ),
            if (_loading || _saving)
              const LinearProgressIndicator(minHeight: 2),
            if (_error != null) _errorBanner(),
            Expanded(child: _body()),
          ],
        ),
      ),
    ),
  );

  Widget _errorBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
    color: Theme.of(context).colorScheme.errorContainer,
    child: Text(
      _details != null && _needsRefresh
          ? 'Данные требуют обновления. $_error'
          : _error!,
      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
    ),
  );

  Widget _body() {
    final details = _details;
    if (details == null) {
      return Center(
        child: _loading
            ? const CircularProgressIndicator()
            : TextButton(onPressed: _refresh, child: const Text('Повторить')),
      );
    }
    return LayoutBuilder(
      builder: (_, constraints) {
        final main = _mainContent();
        final properties = TaskDetailsProperties(
          task: _task,
          details: details,
          onEdit: _canEdit ? () => _openAction(TaskCardAction.edit) : null,
        );
        if (constraints.maxWidth < 740) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [main, properties],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: SingleChildScrollView(child: main)),
            SizedBox(
              width: 300,
              child: ColoredBox(
                color: context.colors.background,
                child: SingleChildScrollView(child: properties),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _mainContent() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaskDetailsSectionTitle(
          title: 'Описание',
          action: _editingDescription ? null : 'Изменить',
          onAction: _canEdit
              ? () => setState(() {
                  _description.text = _task.description ?? '';
                  _editingDescription = true;
                })
              : null,
        ),
        const SizedBox(height: 12),
        if (_editingDescription)
          _descriptionEditor()
        else
          SelectableText(
            _task.description?.trim().isNotEmpty == true
                ? _task.description!
                : 'Описание пока не добавлено.',
            style: const TextStyle(fontSize: 13, height: 1.7),
          ),
        const SizedBox(height: 28),
        const TaskDetailsSectionTitle(title: 'Подзадачи'),
        const SizedBox(height: 12),
        TaskDetailsChecklist(
          subtasks: _task.subtasks,
          onChanged: _canEdit && !_editingDescription ? _markSubtask : null,
        ),
        if (_closed) ...[
          const SizedBox(height: 20),
          Text(
            'Задача закрыта. Доступен только просмотр.',
            style: TextStyle(fontSize: 12, color: context.colors.textMutted),
          ),
        ],
      ],
    ),
  );

  Widget _descriptionEditor() => Form(
    key: _descriptionForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('task-description-editor'),
          controller: _description,
          enabled: !_busy,
          autofocus: true,
          minLines: 6,
          maxLines: 14,
          maxLength: 4000,
          decoration: const InputDecoration(
            hintText: 'Детали задачи и ожидаемый результат',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value != null && value.length > 4000
              ? 'Не больше 4000 символов'
              : null,
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: _busy ? null : _cancelDescription,
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: _canEdit ? _saveDescription : null,
              child: Text(_saving ? 'Сохраняем…' : 'Сохранить описание'),
            ),
          ],
        ),
      ],
    ),
  );
}
