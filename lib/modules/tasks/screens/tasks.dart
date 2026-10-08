import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/core/widgets/material_button.dart';
import 'package:appflowy_board/appflowy_board.dart';
import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/models/tasks.dart';
import 'package:crm_interface/modules/tasks/models/task_column.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/create_task.dart';
import 'package:crm_interface/modules/tasks/widgets/create_column.dart';
import 'package:crm_interface/modules/tasks/widgets/task_card.dart';
import 'package:flutter/material.dart';

import '../repos/request_error.dart';
import '../widgets/task_column_header.dart';
import '../widgets/task_column_footer.dart';
import '../widgets/column_actions.dart';
import '../widgets/column_decoration.dart';
import '../widgets/task_actions.dart';
import '../widgets/move_task_reason.dart';
import '../widgets/task_history.dart';

class TasksCanbanCard extends AppFlowyGroupItem {
  TasksCanbanCard({required this.task});

  final TaskboardTask task;

  @override
  String get id => task.id;
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.tasksRepository});

  final TasksRepository tasksRepository;

  @override
  State<StatefulWidget> createState() {
    return _TasksScreenState();
  }
}

class _TasksScreenState extends State<TasksScreen> {
  late final AppFlowyBoardController _controller;
  final _boardScrollController = ScrollController();
  bool _isChangingColumn = false;
  List<TaskboardColumn> _columns = [];
  bool _isCreating = false;
  bool _isCreatingColumn = false;
  bool _isBoardLoaded = false;
  bool _isOpeningTaskForm = false;
  bool _isOpeningTaskAction = false;
  bool _isMovingTask = false;
  int _boardRequestId = 0;

  Future<void> _loadBoard(AppFlowyBoardController controller) async {
    final requestId = ++_boardRequestId;
    try {
      final Taskboard taskboard = await widget.tasksRepository.getTaskBoard();
      if (!mounted || requestId != _boardRequestId) return;
      controller.clear();
      for (final column in taskboard.columns) {
        controller.addGroup(
          AppFlowyGroupData(id: column.id, name: column.name, items: []),
        );
      }
      for (final task in taskboard.tasks) {
        controller.addGroupItem(task.columnId, TasksCanbanCard(task: task));
      }
      setState(() {
        _columns = taskboard.columns;
        _isBoardLoaded = true;
      });
      if (taskboard.truncated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Показаны не все задачи: достигнут лимит доски.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted || requestId != _boardRequestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is TaskRequestException
                ? error.message
                : 'Не удалось загрузить задачи. Попробуйте ещё раз.',
          ),
        ),
      );
    }
  }

  Future<void> _moveTask(TaskboardTask task, String toColumnId) async {
    if (_isMovingTask) return;
    _boardRequestId++;
    setState(() => _isMovingTask = true);
    _controller.enableGroupDragging(false);
    try {
      final target = _columns.firstWhere((column) => column.id == toColumnId);
      final currentStatus =
          task.status ??
          _columns.firstWhere((column) => column.id == task.columnId).status;
      String? reason;
      if (target.status != currentStatus &&
          const {'rework', 'confirmed', 'cancelled'}.contains(target.status)) {
        reason = await askTaskMoveReason(context);
        if (!mounted) return;
        if (reason == null) {
          await _applyTask(task);
          return;
        }
      }
      final updated = await widget.tasksRepository.moveTask(
        task.id,
        MoveTaskRequest(
          columnId: int.parse(toColumnId),
          version: task.version,
          reason: reason,
        ),
      );
      await _applyTask(updated);
    } on TaskRequestException catch (error) {
      if (!mounted) return;
      await _applyTask(task);
      // A conflict/timeout may mean server state already changed: re-read it.
      await _loadBoard(_controller);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Перенос не подтверждён: ${error.message}')),
        );
      }
    } on FormatException {
      if (!mounted) return;
      await _applyTask(task);
      await _loadBoard(_controller);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось подтвердить перенос задачи'),
          ),
        );
      }
    } finally {
      if (mounted) {
        _controller.enableGroupDragging(true);
        setState(() => _isMovingTask = false);
      }
    }
  }

  Future<void> _createTask(
    AppFlowyBoardController controller,
    CreateTaskRequest task,
  ) async {
    setState(() => _isCreating = true);
    try {
      final newTask = await widget.tasksRepository.createTask(task);
      if (!mounted) return;
      _boardRequestId++;
      controller.addGroupItem(newTask.columnId, TasksCanbanCard(task: newTask));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _createColumn(CreateTaskColumnRequest request) async {
    setState(() => _isCreatingColumn = true);
    try {
      final column = await widget.tasksRepository.createColumn(request);
      if (!mounted) return;
      _boardRequestId++;
      _controller.addGroup(
        AppFlowyGroupData(id: column.id, name: column.name, items: []),
      );
      setState(() => _columns = [..._columns, column]);
    } finally {
      if (mounted) setState(() => _isCreatingColumn = false);
    }
  }

  Future<void> _markSubtask(
    TaskboardTask task,
    TaskboardTaskSubtask subtask,
    bool done,
  ) async {
    final updated = await widget.tasksRepository.markSubtask(
      task.id,
      subtask.id,
      MarkSubtaskRequest(done: done, version: task.version),
    );
    await _applyTask(updated);
  }

  Future<void> _applyTask(TaskboardTask updated) async {
    if (!mounted) return;
    _boardRequestId++;
    if (!_controller.groupIds.contains(updated.columnId)) {
      await _loadBoard(_controller);
      return;
    }
    // A local drag may differ from server placement; don't duplicate the card.
    for (final group in _controller.groupDatas.toList()) {
      if (group.id != updated.columnId &&
          group.items.any((item) => item.id == updated.id)) {
        _controller.removeGroupItem(group.id, updated.id);
      }
    }
    _controller.updateGroupItem(
      updated.columnId,
      TasksCanbanCard(task: updated),
    );
  }

  Future<void> _openTaskAction(
    TaskboardTask task,
    TaskCardAction action,
  ) async {
    if (_isOpeningTaskAction || action == TaskCardAction.delete) return;
    _isOpeningTaskAction = true;
    try {
      if (action == TaskCardAction.history) {
        await showDialog<void>(
          context: context,
          builder: (_) => TaskHistoryWindow(
            taskId: task.id,
            repository: widget.tasksRepository,
          ),
        );
        return;
      }
      final employees = action == TaskCardAction.assign
          ? await widget.tasksRepository.getEmployees()
          : <TaskEmployee>[];
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TaskActionWindow(
          task: task,
          action: action,
          employees: employees,
          searchCustomers: widget.tasksRepository.searchCustomers,
          onEdit: (request) async {
            final updated = await widget.tasksRepository.editTask(
              task.id,
              request,
            );
            await _applyTask(updated);
          },
          onAssign: (request) async {
            final updated = await widget.tasksRepository.assignTask(
              task.id,
              request,
            );
            await _applyTask(updated);
          },
        ),
      );
    } on TaskRequestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть форму. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      _isOpeningTaskAction = false;
    }
  }

  Future<void> _openCreateColumn() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateTaskColumnWindow(onCreate: _createColumn),
    );
  }

  Future<void> _openColumnAction(
    String columnId,
    TaskColumnAction action,
  ) async {
    if (_isChangingColumn) return;
    final column = _columns.where((item) => item.id == columnId).firstOrNull;
    if (column == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TaskColumnActionWindow(
        column: column,
        action: action,
        targets: _columns
            .where(
              (item) =>
                  item.id != column.id &&
                  (item.status == null ||
                      column.status == null ||
                      item.status == column.status),
            )
            .toList(),
        lastStatusColumn:
            column.status != null &&
            _columns.where((item) => item.status == column.status).length == 1,
        canArchiveWithoutTarget:
            column.status == null &&
            (_controller.getGroupController(column.id)?.items.isEmpty ?? false),
        onRename: (name) async {
          setState(() => _isChangingColumn = true);
          try {
            final updated = await widget.tasksRepository.renameColumn(
              column.id,
              RenameTaskColumnRequest(name: name, version: column.version),
            );
            if (!mounted) return;
            _boardRequestId++;
            _controller
                .getGroupController(column.id)
                ?.updateGroupName(updated.name);
            setState(
              () => _columns = [
                for (final item in _columns)
                  item.id == updated.id ? updated : item,
              ],
            );
          } finally {
            if (mounted) setState(() => _isChangingColumn = false);
          }
        },
        onArchive: (targetId) async {
          setState(() => _isChangingColumn = true);
          try {
            await widget.tasksRepository.archiveColumn(
              column.id,
              moveToColumnId: targetId,
            );
            if (!mounted) return;
            // Remove a confirmed archived column even if subsequent GET fails.
            _controller.removeGroup(column.id);
            setState(
              () => _columns = _columns
                  .where((item) => item.id != column.id)
                  .toList(),
            );
            await _loadBoard(_controller);
          } finally {
            if (mounted) setState(() => _isChangingColumn = false);
          }
        },
      ),
    );
  }

  Future<void> _openCreateTask({int? initialColumnId}) async {
    if (_isOpeningTaskForm || !_columns.any((column) => column.canCreateTask)) {
      return;
    }
    if (initialColumnId != null &&
        !_columns.any(
          (column) =>
              int.parse(column.id) == initialColumnId && column.canCreateTask,
        )) {
      return;
    }
    setState(() => _isOpeningTaskForm = true);
    try {
      List<TaskEmployee> employees;
      try {
        employees = await widget.tasksRepository.getEmployees();
      } catch (error) {
        if (!mounted) return;
        employees = [];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Список сотрудников недоступен. Задачу можно создать без ответственного.',
            ),
          ),
        );
      }
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => CreateTaskWindow(
          columns: _columns,
          employees: employees,
          initialColumnId: initialColumnId,
          searchCustomers: widget.tasksRepository.searchCustomers,
          onCreate: (task) => _createTask(_controller, task),
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningTaskForm = false);
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AppFlowyBoardController(
      onMoveGroupItemToGroup: (fromId, fromIndex, toId, toIndex) {
        // AppFlowy calls this after placing the original DTO in the target.
        final item = _controller.getGroupController(toId)!.items[toIndex];
        if (item is TasksCanbanCard) {
          _moveTask(item.task, toId);
        }
      },
    );

    _loadBoard(_controller);
  }

  @override
  void dispose() {
    _boardScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      key: const Key('tasks-move-guard'),
      absorbing: _isMovingTask,
      child: Container(
        padding: EdgeInsets.all(30),
        decoration: BoxDecoration(color: AppColors.background),
        child: Column(
          spacing: 24,
          children: [
            titleBar(),
            if (_isMovingTask) const LinearProgressIndicator(),
            canbanBoard(),
          ],
        ),
      ),
    );
  }

  Widget canbanBoard() {
    return Expanded(
      child: Scrollbar(
        controller: _boardScrollController,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        thickness: 7,
        radius: const Radius.circular(8),
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Align(
            alignment: AlignmentGeometry.topLeft,
            child: AppFlowyBoard(
              key: const ValueKey('template-columns-v2'),
              scrollController: _boardScrollController,
              background: ListenableBuilder(
                listenable: _controller,
                builder: (_, _) => SizedBox.expand(
                  child: CustomPaint(
                    painter: TaskColumnFrames(
                      columns: _controller.groupDatas.length,
                      scrollController: _boardScrollController,
                    ),
                  ),
                ),
              ),
              groupConstraints: const BoxConstraints.tightFor(
                width: TaskColumnFrames.slotWidth,
              ),
              controller: _controller,
              config: const AppFlowyBoardConfig(
                groupBackgroundColor: Colors.transparent,
                groupCornerRadius: 16,
                groupMargin: EdgeInsets.symmetric(horizontal: 8),
                groupBodyPadding: EdgeInsets.symmetric(horizontal: 2),
                stretchGroupHeight: true,
              ),
              headerBuilder: (context, groupData) {
                return ListenableBuilder(
                  listenable: _controller.getGroupController(groupData.id)!,
                  builder: (context, _) => TaskColumnHeader(
                    title: groupData.headerData.groupName,
                    taskCount: groupData.items
                        .whereType<TasksCanbanCard>()
                        .length,
                    onAction: (action) =>
                        _openColumnAction(groupData.id, action),
                  ),
                );
              },
              footerBuilder: (context, groupData) {
                final column = _columns
                    .where((column) => column.id == groupData.id)
                    .firstOrNull;
                return TaskColumnFooter(
                  onCreate:
                      column?.canCreateTask == true &&
                          !_isCreating &&
                          !_isOpeningTaskForm
                      ? () => _openCreateTask(
                          initialColumnId: int.parse(groupData.id),
                        )
                      : null,
                );
              },
              cardBuilder: (context, groupData, item) {
                final card = item as TasksCanbanCard;
                return TaskCard(
                  key: ValueKey(card.id),
                  task: card.task,
                  onAction: (action) => _openTaskAction(card.task, action),
                  onSubtaskChanged: (subtask, done) =>
                      _markSubtask(card.task, subtask, done),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget titleBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Задачи',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight(650),
            letterSpacing: -0.5,
          ),
        ),
        Row(
          spacing: 9,
          children: [
            squareButton(
              '+ Колонка',
              Colors.white,
              Colors.black,
              AppColors.notActiveBorder,
              100,
              40,
              !_isBoardLoaded || _isCreatingColumn ? null : _openCreateColumn,
            ),
            squareButton(
              'Добавить задачу',
              AppColors.activeElement,
              Colors.white,
              AppColors.notActiveBorder,
              155,
              40,
              !_columns.any((column) => column.canCreateTask) ||
                      _isCreating ||
                      _isOpeningTaskForm
                  ? null
                  : _openCreateTask,
            ),
          ],
        ),
      ],
    );
  }
}
