import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/customer_activity.dart';
import '../../../repos/customers_repository.dart';

class CustomerActivityPanel extends StatefulWidget {
  const CustomerActivityPanel({
    super.key,
    required this.customerId,
    required this.repository,
    this.reloadToken = 0,
  });
  final int customerId;
  final CustomersRepository repository;
  final int reloadToken;

  @override
  State<CustomerActivityPanel> createState() => _CustomerActivityPanelState();
}

class _CustomerActivityPanelState extends State<CustomerActivityPanel>
    with AutomaticKeepAliveClientMixin {
  CustomerActivityPage? _page;
  CustomerActivityType? _type;
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomerActivityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) {
      _type = null;
      _page = null;
      _load();
    } else if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load({int offset = 0}) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.getActivity(
        widget.customerId,
        offset: offset,
        type: _type,
      );
      if (mounted && requestId == _requestId) setState(() => _page = page);
    } on CustomerRequestException catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final page = _page;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<CustomerActivityType>(
                key: ValueKey(widget.customerId),
                initialValue: _type,
                isExpanded: true,
                hint: const Text('Все события'),
                decoration: const InputDecoration(
                  labelText: 'Тип события',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<CustomerActivityType>(
                    child: Text('Все события'),
                  ),
                  for (final type in CustomerActivityType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _type = value;
                    _page = null;
                  });
                  _load();
                },
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Обновить активность',
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(child: _content()),
        if (!_loading &&
            _error == null &&
            page != null &&
            page.total > page.limit)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Предыдущие события',
                onPressed: page.offset == 0
                    ? null
                    : () => _load(
                        offset: (page.offset - page.limit).clamp(0, page.total),
                      ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${page.items.isEmpty ? 0 : page.offset + 1}–${page.offset + page.items.length} из ${page.total}',
              ),
              IconButton(
                tooltip: 'Следующие события',
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

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(
              onPressed: () => _load(),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    final items = _page!.items;
    if (items.isEmpty) return const Center(child: Text('Событий пока нет'));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) => CustomerActivityTile(event: items[index]),
    );
  }
}

class CustomerActivityTile extends StatelessWidget {
  const CustomerActivityTile({super.key, required this.event});
  final CustomerActivity event;

  @override
  Widget build(BuildContext context) {
    final type = event.type;
    final data = event.data;
    final icon = switch (event.entityType) {
      'note' => Icons.notes_rounded,
      'task' => Icons.task_alt,
      _ => Icons.person_outline,
    };
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type?.label ?? 'Событие: ${event.rawType}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (data.title != null) Text(data.title!),
                  if (type == CustomerActivityType.responsibleChanged ||
                      type == CustomerActivityType.taskResponsibleChanged)
                    Text(
                      '${data.fromEmployee?.fullName ?? 'Без ответственного'} → ${data.toEmployee?.fullName ?? 'Без ответственного'}',
                    ),
                  if (type == CustomerActivityType.taskStatusChanged)
                    Text(
                      '${_status(data.fromStatus)} → ${_status(data.toStatus)}',
                    ),
                  if (type == CustomerActivityType.taskCreated)
                    Text(_status(data.status)),
                  if (data.reason != null && data.reason!.isNotEmpty)
                    Text('Причина: ${data.reason}'),
                  const SizedBox(height: 5),
                  Text(
                    '${event.actor?.fullName ?? 'Система / автор неизвестен'} · ${DateFormat('dd.MM.yyyy HH:mm').format(event.occurredAt.toLocal())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
