import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:crm_interface/modules/customers/models/create_customer.dart';
import 'package:crm_interface/modules/customers/widgets/create_customer.dart';
import 'package:crm_interface/modules/customers/repos/customers_repository.dart';

import 'customer_identity.dart';

import 'package:flutter/material.dart';

class EntityPanel extends StatefulWidget {
  const EntityPanel({
    super.key,
    required this.apiClient,
    required this.onCustomerSelected,
  });

  final ApiClient apiClient;
  final String title = 'Клиенты';
  final ValueChanged<Customer> onCustomerSelected;

  @override
  State<EntityPanel> createState() => _ListPanelState();
}

class _ListPanelState extends State<EntityPanel> {
  late Future<List<Customer>> customersFuture;
  late final CustomersRepository _repository;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isSearchPending = false;
  int? selectedCustomerId;

  @override
  void initState() {
    super.initState();

    _repository = CustomersRepository(widget.apiClient);
    customersFuture = _repository.getCustomers();
  }

  void _refreshCustomers() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    final future = _repository.getCustomers(search: query);
    // FutureBuilder подпишется в следующем кадре. Быстрый отказ API не должен
    // стать unhandled до rebuild; сам Future сохраняет ошибку для snapshot.
    future.ignore();
    setState(() {
      _searchQuery = query;
      _isSearchPending = false;
      customersFuture = future;
    });
  }

  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    final query = text.trim();
    if (query == _searchQuery) {
      setState(() => _isSearchPending = false);
      return;
    }
    if (query.isEmpty) {
      _refreshCustomers();
      return;
    }
    setState(() => _isSearchPending = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _refreshCustomers();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _refreshCustomers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateCustomer() async {
    final created = await showDialog<CreatedCustomerResponse>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateCustomerWindow(
        loadOptions: _repository.getCreationOptions,
        onCreate: _repository.createCustomer,
      ),
    );
    if (!mounted || created == null) return;
    // POST возвращает краткий результат, не карточку списка. Перечитываем API.
    _refreshCustomers();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Клиент создан')));
  }

  void selectCustomer(int customerId) {
    setState(() {
      selectedCustomerId = customerId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.notActiveBorder, width: 1),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.notActiveBorder, width: 1),
          ),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: AppColors.notActiveBorder),
                ),
              ),
              padding: EdgeInsets.all(20),
              child: listPanelHead(),
            ),
            Expanded(child: customersList()),
          ],
        ),
      ),
    );
  }

  Widget listPanelHead() {
    return Column(
      spacing: 10,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titleArea(),
        TextField(
          key: const Key('customer-list-search'),
          controller: _searchController,
          maxLength: 100,
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _refreshCustomers(),
          decoration: InputDecoration(
            labelText: "⌕ Поиск",
            hintText: 'Имя, телефон или email',
            counterText: '',
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Очистить поиск клиентов',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close, size: 18),
                  ),
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.notActiveBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.notActiveBorder),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        SingleChildScrollView(
          key: const Key('customer-list-filters'),
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 8,
            children: [
              filterButton("Все"),
              filterButton("Мои"),
              filterButton("Без ответственного"),
            ],
          ),
        ),
      ],
    );
  }

  Widget customerButton({required Customer customer}) {
    bool customerSelected = selectedCustomerId == customer.id;
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: customerSelected == false
            ? Border.all(color: Colors.transparent)
            : Border(
                left: BorderSide(color: AppColors.activeElement, width: 3),
              ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              spacing: 10,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.notActiveBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    customerNameIcon(customer.fullName),
                    style: TextStyle(
                      color: Color.fromARGB(255, 71, 84, 103),
                      fontWeight: FontWeight(700),
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    spacing: 3,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight(600),
                        ),
                      ),
                      Text(
                        customer.primaryContact?.trim().isNotEmpty == true
                            ? customer.primaryContact!.trim()
                            : 'Контакт не указан',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMutted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        customer.responsible?.fullName ?? 'Без ответственного',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMutted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget addCostumerButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        fixedSize: const Size(30, 30),
        minimumSize: Size.zero,
        backgroundColor: AppColors.activeElement,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: _openCreateCustomer,
      child: Text('+', style: TextStyle(color: Colors.white)),
    );
  }

  Widget titleArea() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.title,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight(700)),
        ),
        addCostumerButton(),
      ],
    );
  }

  Widget filterButton(String text) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        minimumSize: Size(35, 35),
        foregroundColor: Colors.grey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.notActiveBorder),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight(400), fontSize: 12),
      ),
    );
  }

  Widget customersList() {
    return FutureBuilder<List<Customer>>(
      future: customersFuture,
      builder: (context, snapshot) {
        if (_isSearchPending ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(snapshot.error.toString(), textAlign: TextAlign.center),
                TextButton(
                  onPressed: _refreshCustomers,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }
        final customers = snapshot.data ?? [];

        if (customers.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'Клиентов не найдено'
                  : 'По запросу клиенты не найдены',
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(top: 5),
          itemCount: customers.length,
          itemBuilder: ((context, index) {
            final customer = customers[index];
            bool customerSelected = selectedCustomerId == customer.id;
            return Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: customerSelected
                        ? AppColors.hoveredElement
                        : Colors.transparent,
                    offset: Offset(0, 10),
                    blurRadius: 10,
                    spreadRadius: -20,
                    blurStyle: BlurStyle.normal,
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(vertical: 3, horizontal: 10),
              child: Material(
                color: customerSelected ? Colors.white : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    widget.onCustomerSelected(customer);
                    selectCustomer(customer.id);
                  },
                  child: customerButton(customer: customer),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
