import 'package:flutter/material.dart';
import 'package:crm_interface/core/widgets/section_refresh_controller.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/light/colorscheme.dart';
import '../models/taskboard.dart';
import '../repos/request_error.dart';
import '../repos/tasks.dart';

/// Краткий обзор одной ближайшей незавершённой задачи клиента.
class CustomerNextTask extends StatefulWidget {
  const CustomerNextTask({
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
  State<CustomerNextTask> createState() => _CustomerNextTaskState();
}

class _CustomerNextTaskState extends State<CustomerNextTask> {
  void _bindRefresh() => widget.refreshController?.attach(
    this,
    refresh: _load,
    busy: () => _loading || _saving,
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

  TaskboardTask? _task;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _bindRefresh();
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomerNextTask oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshController != widget.refreshController) {
      oldWidget.refreshController?.detach(this);
      _bindRefresh();
    }
    if (oldWidget.customerId != widget.customerId ||
        oldWidget.reloadToken != widget.reloadToken ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _task = null;
    });
    try {
      final task = await widget.repository.getClosestCustomerTask(
        widget.customerId,
      );
      if (mounted && requestId == _requestId) setState(() => _task = task);
    } on TaskRequestException catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = error.message);
      }
    } on FormatException {
      if (mounted && requestId == _requestId) {
        setState(() => _error = 'Некорректный ответ с задачами клиента');
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  bool _canStart(TaskboardTask? task) =>
      task != null &&
      const {'new', 'rework'}.contains(task.status) &&
      task.responsibleEmployeeId != null;

  String _actionHint(TaskboardTask? task) {
    if (task == null) return 'Нет задачи для завершения';
    if (const {'new', 'rework'}.contains(task.status)) {
      return task.responsibleEmployeeId == null
          ? 'Сначала назначьте исполнителя в задачнике'
          : 'Перевести в работу может исполнитель задачи';
    }
    return 'Завершение доступно исполнителю задачи в работе';
  }

  Future<void> _changeStatus() async {
    final task = _task;
    if (_saving ||
        _loading ||
        task == null ||
        (!_canStart(task) && task.status != 'in_progress')) {
      return;
    }
    final customerId = widget.customerId;
    setState(() => _saving = true);
    try {
      if (_canStart(task)) {
        await widget.repository.startTask(task.id);
      } else {
        await widget.repository.completeTask(task.id);
      }
      if (!mounted || widget.customerId != customerId) return;
      widget.onChanged?.call();
      await _load();
    } on TaskRequestException catch (error) {
      if (mounted && widget.customerId == customerId) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FormatException {
      if (mounted && widget.customerId == customerId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Некорректный ответ при изменении статуса задачи'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    final needsStart =
        task != null && const {'new', 'rework'}.contains(task.status);
    final actionLabel = needsStart ? 'В работу' : 'Выполнено';
    return Container(
      key: const Key('customer-next-task'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.notActiveBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'БЛИЖАЙШАЯ ЗАДАЧА',
                  style: TextStyle(
                    color: AppColors.activeElement,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          if (_loading)
            const LinearProgressIndicator()
          else if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Повторить')),
          ] else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task?.title ?? 'У клиента нет незавершённых задач',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (task != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${_deadline(task)} • ${task.responsibleEmployeeName ?? 'Нет ответственного'}',
                          style: TextStyle(
                            color: AppColors.textMutted,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          switch (task.status) {
                            'new' => 'Новая',
                            'in_progress' => 'В работе',
                            'rework' => 'На доработке',
                            _ => 'Неизвестный статус',
                          },
                          style: TextStyle(
                            color: AppColors.textMutted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (task != null) ...[
                  const SizedBox(width: 12),
                  Tooltip(
                    message: _actionHint(task),
                    child: ElevatedButton(
                      onPressed:
                          (_canStart(task) || task.status == 'in_progress') &&
                              !_saving
                          ? _changeStatus
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        backgroundColor: AppColors.activeElement,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.notActiveBorder,
                        disabledForegroundColor: AppColors.textMutted,
                        fixedSize: const Size(100, 37),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(_saving ? 'Сохранение' : actionLabel),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  String _deadline(TaskboardTask task) {
    if (task.dueDate != null) {
      return 'Срок до: ${DateFormat('dd.MM.yyyy').format(task.dueDate!)}';
    }
    if (task.dueAt != null) {
      return 'Срок до: ${DateFormat('dd.MM.yyyy HH:mm').format(task.dueAt!.toLocal())}';
    }
    return 'Без срока';
  }
}
