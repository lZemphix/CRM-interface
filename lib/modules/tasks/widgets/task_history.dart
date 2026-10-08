import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task_details.dart';
import '../repos/tasks.dart';
import '../repos/request_error.dart';

class TaskHistoryWindow extends StatefulWidget {
  const TaskHistoryWindow({
    super.key,
    required this.taskId,
    required this.repository,
  });
  final String taskId;
  final TasksRepository repository;

  @override
  State<TaskHistoryWindow> createState() => _TaskHistoryWindowState();
}

class _TaskHistoryWindowState extends State<TaskHistoryWindow> {
  late Future<TaskDetails> _details;

  @override
  void initState() {
    super.initState();
    _details = widget.repository.getTaskDetails(widget.taskId);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('История задачи'),
    content: SizedBox(
      width: 580,
      height: 420,
      child: FutureBuilder<TaskDetails>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error is TaskRequestException
                        ? error.message
                        : 'Не удалось получить историю задачи',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () {
                      final future = widget.repository.getTaskDetails(
                        widget.taskId,
                      );
                      setState(() {
                        _details = future;
                      });
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }
          final details = snapshot.data;
          if (details == null) {
            return const Center(child: Text('Данные не получены'));
          }
          return _history(details);
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Закрыть'),
      ),
    ],
  );

  Widget _history(TaskDetails details) {
    final entries = <_HistoryEntry>[
      for (final event in details.columnHistory)
        _HistoryEntry(
          at: event.changedAt,
          actor: event.changedBy.fullName,
          reason: event.reason,
          title: event.previousColumn == null
              ? 'Задача создана в колонке «${event.newColumn.name}»'
              : 'Колонка: ${event.previousColumn!.name} → ${event.newColumn.name}',
        ),
      for (final event in details.statusHistory)
        _HistoryEntry(
          at: event.changedAt,
          actor: event.changedBy.fullName,
          reason: event.reason,
          title:
              'Статус: ${_status(event.previousStatus)} → ${_status(event.newStatus)}',
        ),
      for (final event in details.assignmentHistory)
        _HistoryEntry(
          at: event.changedAt,
          actor: event.changedBy.fullName,
          reason: event.reason,
          title:
              'Ответственный: ${event.previousEmployee?.fullName ?? 'Не назначен'} → ${event.newEmployee?.fullName ?? 'Не назначен'}',
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    if (entries.isEmpty) {
      return const Center(child: Text('История задачи пока пуста'));
    }
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 16),
      itemBuilder: (_, index) {
        final entry = entries[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.title),
            if (entry.reason != null && entry.reason!.isNotEmpty)
              Text('Причина: ${entry.reason}'),
            const SizedBox(height: 4),
            Text(
              '${entry.actor} · ${DateFormat('dd.MM.yyyy HH:mm').format(entry.at.toLocal())}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  String _status(String? status) => switch (status) {
    'new' => 'Новая',
    'in_progress' => 'В работе',
    'completed' => 'Выполнена — на проверке',
    'rework' => 'На доработке',
    'confirmed' => 'Подтверждена',
    'cancelled' => 'Отменена',
    null => 'Не указан',
    _ => status,
  };
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.at,
    required this.actor,
    required this.title,
    required this.reason,
  });
  final DateTime at;
  final String actor;
  final String title;
  final String? reason;
}
