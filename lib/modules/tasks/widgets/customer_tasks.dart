import 'package:flutter/material.dart';
import 'package:crm_interface/core/widgets/section_refresh_controller.dart';

import '../models/taskboard.dart';
import '../models/tasks.dart';
import '../repos/request_error.dart';
import '../repos/tasks.dart';
import 'task_actions.dart';
import 'task_card.dart';
import 'task_history.dart';

/// Представление задач модуля tasks, отфильтрованных по одному клиенту.
class CustomerTasksPanel extends StatefulWidget {
  const CustomerTasksPanel({
    super.key,
    required this.customerId,
    required this.repository,
    this.reloadToken = 0,
    this.onChanged,
    this.refreshController,
  });

  final int customerId;
  final TasksRepository repository;
  final int reloadToken;
  final VoidCallback? onChanged;
  final SectionRefreshController? refreshController;

  @override
  State<CustomerTasksPanel> createState() => _CustomerTasksPanelState();
}

class _CustomerTasksPanelState extends State<CustomerTasksPanel> {
  bool _savingSubtask = false;
  void _bindRefresh() => widget.refreshController?.attach(
    this,
    refresh: () => _load(offset: _page?.offset ?? 0),
    busy: () => _loading || _openingAction || _savingSubtask,
  );

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.refreshController?.changed();
  }

  @override
  void dispose() {
    widget.refreshController?.detach(this);
    super.dispose();
  }

  TaskPage? _page;
  bool _loading = true;
  bool _openingAction = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _bindRefresh();
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomerTasksPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshController != widget.refreshController) {
      oldWidget.refreshController?.detach(this);
      _bindRefresh();
    }
    if (oldWidget.customerId != widget.customerId ||
        oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load({int offset = 0}) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.getCustomerTasks(
        widget.customerId,
        offset: offset,
      );
      if (mounted && id == _requestId) setState(() => _page = page);
    } on TaskRequestException catch (error) {
      if (mounted && id == _requestId) setState(() => _error = error.message);
    } on FormatException {
      if (mounted && id == _requestId) {
        setState(() => _error = 'Некорректный список задач');
      }
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _apply(TaskboardTask updated) async {
    if (!mounted) return;
    if (updated.customerId != widget.customerId) {
      await _load();
      if (mounted) widget.onChanged?.call();
      return;
    }
    final page = _page!;
    // Ответ предыдущего GET не должен затереть уже сохранённую правку.
    _requestId++;
    setState(() {
      _loading = false;
      _page = TaskPage(
        items: [
          for (final task in page.items)
            task.id == updated.id && updated.version >= task.version
                ? updated
                : task,
        ],
        total: page.total,
        limit: page.limit,
        offset: page.offset,
      );
    });
    widget.onChanged?.call();
  }

  Future<void> _openAction(TaskboardTask task, TaskCardAction action) async {
    if (_openingAction || action == TaskCardAction.delete) return;
    _openingAction = true;
    widget.refreshController?.changed();
    try {
      if (action == TaskCardAction.history) {
        await showDialog<void>(
          context: context,
          builder: (_) =>
              TaskHistoryWindow(taskId: task.id, repository: widget.repository),
        );
        return;
      }
      final employees = action == TaskCardAction.assign
          ? await widget.repository.getEmployees()
          : <TaskEmployee>[];
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TaskActionWindow(
          task: task,
          action: action,
          employees: employees,
          searchCustomers: widget.repository.searchCustomers,
          onEdit: (request) async =>
              _apply(await widget.repository.editTask(task.id, request)),
          onAssign: (request) async =>
              _apply(await widget.repository.assignTask(task.id, request)),
        ),
      );
    } on TaskRequestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      _openingAction = false;
      widget.refreshController?.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Column(
      children: [
        Expanded(child: _buildContent()),
        if (!_loading &&
            _error == null &&
            page != null &&
            page.total > page.limit)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Предыдущие задачи',
                onPressed: page.offset == 0
                    ? null
                    : () => _load(
                        offset: (page.offset - page.limit)
                            .clamp(0, page.total)
                            .toInt(),
                      ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${page.offset + 1}–${page.offset + page.items.length} из ${page.total}',
              ),
              IconButton(
                tooltip: 'Следующие задачи',
                onPressed: page.offset + page.limit >= page.total
                    ? null
                    : () => _load(offset: page.offset + page.limit),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(
              onPressed: () => _load(offset: _page?.offset ?? 0),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    final tasks = _page!.items;
    if (tasks.isEmpty) {
      return const Center(child: Text('У клиента пока нет задач'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final task = tasks[index];
        return TaskCard(
          key: ValueKey(task.id),
          task: task,
          compact: true,
          onAction: (action) => _openAction(task, action),
          onSubtaskChanged: (subtask, done) async {
            if (_savingSubtask) return;
            _savingSubtask = true;
            widget.refreshController?.changed();
            try {
              final updated = await widget.repository.markSubtask(
                task.id,
                subtask.id,
                MarkSubtaskRequest(done: done, version: task.version),
              );
              await _apply(updated);
            } finally {
              _savingSubtask = false;
              widget.refreshController?.changed();
            }
          },
        );
      },
    );
  }
}
