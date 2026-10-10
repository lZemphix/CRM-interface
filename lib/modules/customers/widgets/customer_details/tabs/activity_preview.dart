import 'package:flutter/material.dart';
import 'package:crm_interface/core/widgets/section_refresh_controller.dart';

import '../../../../../core/theme/light/colorscheme.dart';

import '../../../models/customer_activity.dart';
import '../../../repos/customers_repository.dart';
import 'activity_tab.dart';

/// Только последние три события, не последний визит/контакт клиента.
class CustomerActivityPreview extends StatefulWidget {
  const CustomerActivityPreview({
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
  State<CustomerActivityPreview> createState() =>
      _CustomerActivityPreviewState();
}

class _CustomerActivityPreviewState extends State<CustomerActivityPreview> {
  late Future<CustomerActivityPage> _future;
  bool _loading = false;

  void _bindRefresh() => widget.refreshController?.attach(
    this,
    refresh: _refresh,
    busy: () => _loading,
  );

  @override
  void dispose() {
    widget.refreshController?.detach(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _bindRefresh();
    _future = _load();
  }

  int _requestId = 0;
  Future<CustomerActivityPage> _load() async {
    final id = ++_requestId;
    _loading = true;
    widget.refreshController?.changed();
    try {
      return await widget.repository.getActivity(widget.customerId, limit: 3);
    } finally {
      if (mounted && id == _requestId) {
        _loading = false;
        widget.refreshController?.changed();
      }
    }
  }

  @override
  void didUpdateWidget(covariant CustomerActivityPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshController != widget.refreshController) {
      oldWidget.refreshController?.detach(this);
      _bindRefresh();
    }
    if (oldWidget.customerId != widget.customerId ||
        oldWidget.reloadToken != widget.reloadToken ||
        oldWidget.repository != widget.repository) {
      _future = _load();
    }
  }

  Future<void> _refresh() async {
    final future = _load();
    future.ignore();
    setState(() {
      _future = future;
    });
    // FutureBuilder renders the error; the shared button only waits for completion.
    try {
      await future;
    } on CustomerRequestException {
      return;
    } on FormatException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.notActiveBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    child: FutureBuilder<CustomerActivityPage>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.error;
        final events = snapshot.data?.items.take(3).toList() ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Последняя активность',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (loading)
              const LinearProgressIndicator()
            else if (error != null) ...[
              Text(
                error is CustomerRequestException
                    ? error.message
                    : 'Не удалось получить активность',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _refresh,
                  child: const Text('Повторить'),
                ),
              ),
            ] else if (snapshot.data == null || snapshot.data!.items.isEmpty)
              const Text('Событий пока нет')
            else
              for (var index = 0; index < events.length; index++)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 8 : 0),
                  child: CustomerActivityTile(
                    event: events[index],
                    isLast: index == events.length - 1,
                  ),
                ),
          ],
        );
      },
    ),
  );
}
