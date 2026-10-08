import 'package:flutter/material.dart';

import '../models/tasks.dart';
import '../repos/request_error.dart';

class TaskCustomerField extends StatefulWidget {
  const TaskCustomerField({
    super.key,
    required this.onSelected,
    this.searchCustomers,
    this.initialCustomer,
    this.locked = false,
    this.enabled = true,
  });

  final Future<List<TaskCustomerOption>> Function(String)? searchCustomers;
  final TaskCustomerOption? initialCustomer;
  final ValueChanged<TaskCustomerOption?> onSelected;
  final bool locked;
  final bool enabled;

  @override
  State<TaskCustomerField> createState() => _TaskCustomerFieldState();
}

class _TaskCustomerFieldState extends State<TaskCustomerField> {
  TaskCustomerOption? _selected;
  String? _error;
  int _searchId = 0;
  String? _query;
  Future<Iterable<TaskCustomerOption>>? _pending;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCustomer;
  }

  Future<Iterable<TaskCustomerOption>> _search(TextEditingValue value) {
    final query = value.text.trim();
    // Смена курсора не должна отменять поиск того же текста.
    if (_query == query && _pending != null) return _pending!;
    _query = query;
    _pending = _fetch(query, ++_searchId);
    return _pending!;
  }

  Future<Iterable<TaskCustomerOption>> _fetch(String query, int id) async {
    if (query.isEmpty || widget.searchCustomers == null) {
      if (mounted && _error != null) setState(() => _error = null);
      return const [];
    }
    // Не отправляем запрос для каждого символа; Autocomplete также отсекает
    // устаревшие результаты, если ответ пришёл после следующего ввода.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || id != _searchId) return const [];
    try {
      final found = await widget.searchCustomers!(query);
      if (mounted && id == _searchId) {
        setState(() => _error = found.isEmpty ? 'Клиенты не найдены' : null);
      }
      return found;
    } on TaskRequestException catch (error) {
      if (mounted && id == _searchId) setState(() => _error = error.message);
      return const [];
    } on FormatException {
      if (mounted && id == _searchId) {
        setState(() => _error = 'Некорректный ответ поиска клиентов');
      }
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locked) {
      return TextFormField(
        initialValue: _selected?.fullName,
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Клиент',
          helperText: 'Задача будет связана с этим клиентом',
        ),
      );
    }
    return Autocomplete<TaskCustomerOption>(
      initialValue: TextEditingValue(text: _selected?.fullName ?? ''),
      displayStringForOption: (customer) => customer.fullName,
      optionsBuilder: _search,
      onSelected: (customer) {
        if (!widget.enabled) return;
        setState(() {
          _selected = customer;
          _error = null;
        });
        widget.onSelected(customer);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          key: const Key('task-customer-search'),
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          maxLength: 100,
          decoration: InputDecoration(
            labelText: 'Клиент (необязательно)',
            helperText: _error ?? 'Поиск по имени или контакту. Оставьте пустым для внутренней задачи.',
            helperMaxLines: 3,
            counterText: '',
            suffixIcon: IconButton(
              tooltip: 'Убрать привязку к клиенту',
              onPressed: widget.enabled
                  ? () {
                      controller.clear();
                      setState(() {
                        _selected = null;
                        _error = null;
                      });
                      widget.onSelected(null);
                    }
                  : null,
              icon: const Icon(Icons.close, size: 18),
            ),
          ),
          onChanged: (text) {
            if (_selected != null && text != _selected!.fullName) {
              setState(() => _selected = null);
              widget.onSelected(null);
            }
          },
          onFieldSubmitted: (_) => onSubmitted(),
          validator: (value) =>
              value?.trim().isNotEmpty == true && _selected == null
              ? 'Выберите клиента из подсказок или очистите поле'
              : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final customers = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 360,
              height: (customers.length * 64.0).clamp(0, 240).toDouble(),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: customers.length,
                itemBuilder: (_, index) {
                  final customer = customers[index];
                  return ListTile(
                    title: Text(
                      customer.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      customer.primaryContact ?? 'ID: ${customer.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: widget.enabled ? () => onSelected(customer) : null,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
