import 'package:flutter/material.dart';
import 'package:crm_interface/core/widgets/section_refresh_controller.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/light/colorscheme.dart';
import '../../../models/customer_activity.dart';
import '../../../repos/customers_repository.dart';
import '../timeline_entry.dart';

class CustomerActivityPanel extends StatefulWidget {
  const CustomerActivityPanel({
    super.key,
    required this.customerId,
    required this.repository,
    this.reloadToken = 0,
    this.refreshController,
  });
  final int customerId;
  final CustomersRepository repository;
  final int reloadToken;
  final SectionRefreshController? refreshController;

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

  void _bindRefresh() => widget.refreshController?.attach(
    this,
    refresh: () => _load(offset: _page?.offset ?? 0),
    busy: () => _loading,
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

  @override
  void initState() {
    super.initState();
    _bindRefresh();
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomerActivityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshController != widget.refreshController) {
      oldWidget.refreshController?.detach(this);
      _bindRefresh();
    }
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
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.notActiveBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 250,
                    child: DropdownButtonFormField<CustomerActivityType>(
                      key: ValueKey(widget.customerId),
                      initialValue: _type,
                      isExpanded: true,
                      hint: const Text('Все события'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                      ),
                      iconEnabledColor: AppColors.textMutted,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      menuMaxHeight: 320,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        prefixIcon: const Icon(
                          Icons.filter_list_rounded,
                          size: 16,
                          color: AppColors.textMutted,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 40,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.notActiveBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.notActiveBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.activeElement,
                          ),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<CustomerActivityType>(
                          child: Text('Все события'),
                        ),
                        for (final type in CustomerActivityType.values)
                          DropdownMenuItem(
                            value: type,
                            child: Text(
                              type.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                ),
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
                          offset: (page.offset - page.limit).clamp(
                            0,
                            page.total,
                          ),
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
      ),
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
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, index) => CustomerActivityTile(
        event: items[index],
        isLast: index == items.length - 1,
      ),
    );
  }
}

class CustomerActivityTile extends StatelessWidget {
  const CustomerActivityTile({
    super.key,
    required this.event,
    this.isLast = true,
  });
  final CustomerActivity event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final type = event.type;
    final data = event.data;
    return CustomerTimelineEntry(
      isLast: isLast,
      title: Text(type?.label ?? 'Событие: ${event.rawType}'),
      metadata:
          '${event.actor?.fullName ?? 'Система / автор неизвестен'} · ${DateFormat('dd.MM.yyyy HH:mm').format(event.occurredAt.toLocal())}',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.title != null) Text(data.title!),
          if (type == CustomerActivityType.responsibleChanged ||
              type == CustomerActivityType.taskResponsibleChanged)
            Text(
              '${data.fromEmployee?.fullName ?? 'Без ответственного'} → ${data.toEmployee?.fullName ?? 'Без ответственного'}',
            ),
          if (type == CustomerActivityType.taskStatusChanged)
            Text('${_status(data.fromStatus)} → ${_status(data.toStatus)}'),
          if (type == CustomerActivityType.taskCreated)
            Text(_status(data.status)),
          if (data.reason != null && data.reason!.isNotEmpty)
            Text('Причина: ${data.reason}'),
        ],
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
