import 'package:flutter/material.dart';

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
  });
  final int customerId;
  final CustomersRepository repository;
  final int reloadToken;

  @override
  State<CustomerActivityPreview> createState() =>
      _CustomerActivityPreviewState();
}

class _CustomerActivityPreviewState extends State<CustomerActivityPreview> {
  late Future<CustomerActivityPage> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<CustomerActivityPage> _load() =>
      widget.repository.getActivity(widget.customerId, limit: 3);

  @override
  void didUpdateWidget(covariant CustomerActivityPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId ||
        oldWidget.reloadToken != widget.reloadToken ||
        oldWidget.repository != widget.repository) {
      _future = _load();
    }
  }

  void _refresh() {
    final future = _load();
    future.ignore();
    setState(() {
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: FutureBuilder<CustomerActivityPage>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.error;
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
                IconButton(
                  tooltip: 'Обновить последнюю активность',
                  onPressed: loading ? null : _refresh,
                  icon: const Icon(Icons.refresh, size: 18),
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
              for (final event in snapshot.data!.items.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: CustomerActivityTile(event: event),
                ),
          ],
        );
      },
    ),
  );
}
