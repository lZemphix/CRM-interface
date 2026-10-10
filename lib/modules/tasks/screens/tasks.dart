import 'dart:async';

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
import '../widgets/board_sync.dart';

export '../widgets/board_sync.dart' show TasksCanbanCard;

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.tasksRepository});

  final TasksRepository tasksRepository;

  @override
  State<StatefulWidget> createState() {
    return _TasksScreenState();
  }
}

class _TasksScreenState extends State<TasksScreen> with WidgetsBindingObserver {
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
  Timer? _refreshTimer;
  Future<void>? _boardLoad;
  bool _isLoadingBoard = false;
  bool _isOpeningColumnForm = false;
  bool _wasTruncated = false;
  bool _appActive = true;
  int _pendingSubtasks = 0;
  final Set<int> _boardPointers = {};
  String? _refreshError;

  bool get _refreshBlocked =>
      !_appActive ||
      _boardPointers.isNotEmpty ||
      _controller.groupDatas.any(
        (group) => group.items.any((item) => item.isPhantom),
      ) ||
      _isMovingTask ||
      _isCreating ||
      _isCreatingColumn ||
      _isChangingColumn ||
      _pendingSubtasks > 0 ||
      _isOpeningTaskForm ||
      _isOpeningTaskAction ||
      _isOpeningColumnForm;

  Future<void> _loadBoard(
    AppFlowyBoardController controller, {
    bool automatic = false,
    bool recovery = false,
  }) async {
    if (!mounted) return;
    final current = _boardLoad;
    if (current != null) {
      // Recovery must not be lost behind a GET invalidated by a mutation.
      if (recovery) {
        await current;
        if (mounted) await _loadBoard(controller, recovery: true);
      }
      return;
    }
    if (!recovery && _refreshBlocked) return;
    final load = _fetchBoard(
      controller,
      automatic: automatic,
      recovery: recovery,
    );
    _boardLoad = load;
    try {
      await load;
    } finally {
      _boardLoad = null;
    }
  }

  Future<void> _fetchBoard(
    AppFlowyBoardController controller, {
    required bool automatic,
    required bool recovery,
  }) async {
    final requestId = ++_boardRequestId;
    setState(() => _isLoadingBoard = true);
    try {
      final Taskboard taskboard = await widget.tasksRepository.getTaskBoard();
      if (!mounted ||
          requestId != _boardRequestId ||
          (!recovery && _refreshBlocked)) {
        return;
      }
      synchronizeTaskBoard(controller, taskboard);
      setState(() {
        _columns = taskboard.columns;
        _isBoardLoaded = true;
        _refreshError = null;
      });
      if (taskboard.truncated && !_wasTruncated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Показаны не все задачи: достигнут лимит доски.'),
          ),
        );
      }
      _wasTruncated = taskboard.truncated;
    } catch (error) {
      if (!mounted || requestId != _boardRequestId) return;
      final message = error is TaskRequestException
          ? error.message
          : 'Не удалось загрузить задачи. Попробуйте ещё раз.';
      setState(() => _refreshError = message);
      if (!automatic) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoadingBoard = false);
    }
  }

  Future<void> _moveTask(TaskboardTask task, String toColumnId) async {
    // AppFlowy can report a cross-group drop after a phantom returns home.
    // The saved DTO, not that callback's origin/index, identifies a real move.
    if (_isMovingTask || task.columnId == toColumnId) return;
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
      await _loadBoard(_controller, recovery: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Перенос не подтверждён: ${error.message}')),
        );
      }
    } on FormatException {
      if (!mounted) return;
      await _applyTask(task);
      await _loadBoard(_controller, recovery: true);
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
    _boardRequestId++;
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
    _boardRequestId++;
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
    _boardRequestId++;
    setState(() => _pendingSubtasks++);
    try {
      final updated = await widget.tasksRepository.markSubtask(
        task.id,
        subtask.id,
        MarkSubtaskRequest(done: done, version: task.version),
      );
      await _applyTask(updated);
    } finally {
      _pendingSubtasks--;
      if (mounted) setState(() {});
    }
  }

  Future<void> _applyTask(TaskboardTask updated) async {
    if (!mounted) return;
    _boardRequestId++;
    if (!_controller.groupIds.contains(updated.columnId)) {
      await _loadBoard(_controller, recovery: true);
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
    _boardRequestId++;
    setState(() => _isOpeningTaskAction = true);
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
      if (mounted) setState(() => _isOpeningTaskAction = false);
    }
  }

  Future<void> _openCreateColumn() async {
    if (_isOpeningColumnForm) return;
    _boardRequestId++;
    setState(() => _isOpeningColumnForm = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CreateTaskColumnWindow(onCreate: _createColumn),
      );
    } finally {
      if (mounted) setState(() => _isOpeningColumnForm = false);
    }
  }

  Future<void> _openColumnAction(
    String columnId,
    TaskColumnAction action,
  ) async {
    if (_isChangingColumn || _isOpeningColumnForm) return;
    final column = _columns.where((item) => item.id == columnId).firstOrNull;
    if (column == null) return;
    _boardRequestId++;
    setState(() => _isOpeningColumnForm = true);
    try {
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
              _columns.where((item) => item.status == column.status).length ==
                  1,
          canArchiveWithoutTarget:
              column.status == null &&
              (_controller.getGroupController(column.id)?.items.isEmpty ??
                  false),
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
              _boardRequestId++;
              await _loadBoard(_controller, recovery: true);
            } finally {
              if (mounted) setState(() => _isChangingColumn = false);
            }
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningColumnForm = false);
    }
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
    _boardRequestId++;
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
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appActive = lifecycle == null || lifecycle == AppLifecycleState.resumed;

    _controller = AppFlowyBoardController(
      onMoveGroupItemToGroup: (fromId, fromIndex, toId, toIndex) {
        // AppFlowy calls this after placing the original DTO in the target.
        final item = _controller.getGroupController(toId)!.items[toIndex];
        if (item is TasksCanbanCard) {
          _moveTask(item.task, toId);
        }
      },
    );

    unawaited(_loadBoard(_controller));
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_loadBoard(_controller, automatic: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (!_appActive) {
      _boardRequestId++;
      _boardPointers.clear();
    } else {
      unawaited(_loadBoard(_controller, automatic: true));
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
            if (_refreshError != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_isBoardLoaded ? 'Данные могут быть устаревшими. ' : ''}${_refreshError!}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_isMovingTask) const LinearProgressIndicator(),
            canbanBoard(),
          ],
        ),
      ),
    );
  }

  Widget canbanBoard() {
    if (!_isBoardLoaded) {
      return Expanded(
        child: Center(
          child: _isLoadingBoard
              ? const CircularProgressIndicator()
              : const Text('Доска не загружена. Нажмите «Обновить».'),
        ),
      );
    }
    if (_columns.isEmpty) {
      return const Expanded(
        child: Center(child: Text('Нет колонок. Добавьте первую колонку.')),
      );
    }
    return Expanded(
      child: Listener(
        onPointerDown: (event) {
          _boardPointers.add(event.pointer);
          _boardRequestId++;
        },
        onPointerUp: (event) => _boardPointers.remove(event.pointer),
        onPointerCancel: (event) => _boardPointers.remove(event.pointer),
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
              _isLoadingBoard ? 'Обновление…' : 'Обновить',
              Colors.white,
              Colors.black,
              AppColors.notActiveBorder,
              115,
              40,
              _isLoadingBoard || _refreshBlocked
                  ? null
                  : () => _loadBoard(_controller),
            ),
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
