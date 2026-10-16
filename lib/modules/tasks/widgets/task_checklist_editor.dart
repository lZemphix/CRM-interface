import 'package:flutter/material.dart';

import '../models/tasks.dart';

class TaskChecklistEditor extends StatefulWidget {
  const TaskChecklistEditor({
    super.key,
    required this.initialSubtasks,
    required this.enabled,
    required this.onChanged,
  });

  final List<TaskSubtaskDraft> initialSubtasks;
  final bool enabled;
  final ValueChanged<List<TaskSubtaskDraft>> onChanged;

  @override
  State<TaskChecklistEditor> createState() => _TaskChecklistEditorState();
}

class _ChecklistRow {
  _ChecklistRow(TaskSubtaskDraft draft)
    : id = draft.id,
      controller = TextEditingController(text: draft.title);
  final int? id;
  final key = UniqueKey();
  final TextEditingController controller;
}

class _TaskChecklistEditorState extends State<TaskChecklistEditor> {
  late final List<_ChecklistRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialSubtasks.map(_ChecklistRow.new).toList();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  void _notify() => widget.onChanged([
    for (final row in _rows)
      TaskSubtaskDraft(id: row.id, title: row.controller.text.trim()),
  ]);

  void _add() {
    if (!widget.enabled || _rows.length >= 50) return;
    setState(() => _rows.add(_ChecklistRow(const TaskSubtaskDraft(title: ''))));
    _notify();
  }

  void _remove(int index) {
    if (!widget.enabled) return;
    final row = _rows[index];
    setState(() => _rows.removeAt(index));
    // EditableText still owns the controller until the next frame unmounts it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => row.controller.dispose(),
    );
    _notify();
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (!widget.enabled || target < 0 || target >= _rows.length) return;
    setState(() {
      final row = _rows.removeAt(index);
      _rows.insert(target, row);
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Подзадачи', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (_rows.isEmpty)
        const Text('Подзадач нет. Можно добавить шаги выполнения.'),
      for (var i = 0; i < _rows.length; i++) _row(i),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: widget.enabled && _rows.length < 50 ? _add : null,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Добавить подзадачу'),
        ),
      ),
      if (_rows.length >= 50) const Text('Не больше 50 подзадач.'),
    ],
  );

  Widget _row(int index) => Padding(
    key: _rows[index].key,
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _rows[index].controller,
            enabled: widget.enabled,
            maxLength: 255,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Что нужно сделать?',
              counterText: '',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Введите название или уберите строку'
                : value.trim().length > 255
                ? 'Не больше 255 символов'
                : null,
            onChanged: (_) => _notify(),
          ),
        ),
        const SizedBox(width: 4),
        _rowButton(
          Icons.arrow_upward,
          'Поднять подзадачу',
          widget.enabled && index > 0 ? () => _move(index, -1) : null,
        ),
        _rowButton(
          Icons.arrow_downward,
          'Опустить подзадачу',
          widget.enabled && index < _rows.length - 1
              ? () => _move(index, 1)
              : null,
        ),
        _rowButton(
          Icons.close,
          'Убрать подзадачу',
          widget.enabled ? () => _remove(index) : null,
        ),
      ],
    ),
  );

  Widget _rowButton(IconData icon, String tooltip, VoidCallback? onPressed) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
        visualDensity: VisualDensity.compact,
      );
}
