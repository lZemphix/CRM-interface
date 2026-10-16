import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/theme/app_palette.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:crm_interface/modules/customers/widgets/customer_details/detail_panel.dart';
import 'package:crm_interface/modules/customers/widgets/entity_panel.dart';
import 'package:flutter/material.dart';
import 'package:crm_interface/core/keyboard/command_scope.dart';
import 'package:crm_interface/core/keyboard/keybindings.dart';
import 'package:crm_interface/core/keyboard/search_shortcut_scope.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<StatefulWidget> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  Customer? selectedCustomer;
  int _listReloadToken = 0;

  void selectCustomer(Customer customer) {
    setState(() {
      selectedCustomer = customer;
    });
  }

  @override
  Widget build(BuildContext context) {
    final customer = selectedCustomer;
    return RegisterSearchFocus(
      node: _searchFocus,
      child: CommandScope(
        commands: {AppCommand.focusSearch: _searchFocus.requestFocus},
        child: Container(
          color: context.colors.background,
          child: Row(
            children: [
              SizedBox(
                width: 320,
                child: EntityPanel(
                  searchFocusNode: _searchFocus,
                  apiClient: widget.apiClient,
                  onCustomerSelected: selectCustomer,
                  reloadToken: _listReloadToken,
                ),
              ),
              Expanded(
                child: customer == null
                    ? const Center(child: Text("Выберите клиента."))
                    : DetailPanel(
                        customer: customer,
                        apiClient: widget.apiClient,
                        onCustomerChanged: () =>
                            setState(() => _listReloadToken++),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
