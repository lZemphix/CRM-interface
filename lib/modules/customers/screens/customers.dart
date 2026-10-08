import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:crm_interface/modules/customers/widgets/customer_details/detail_panel.dart';
import 'package:crm_interface/modules/customers/widgets/entity_panel.dart';
import 'package:flutter/material.dart';


class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<StatefulWidget> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
    
  Customer? selectedCustomer;

  void selectCustomer(Customer customer) {
    setState(() {
      selectedCustomer = customer;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final customer = selectedCustomer;
    return Container(
      color: AppColors.background,
      child: Row(
      children: [
        SizedBox(
          width: 320,
          child: EntityPanel(
            apiClient: widget.apiClient,
            onCustomerSelected: selectCustomer,
          ),
        ),
        Expanded(
          child: customer == null
              ? const Center(child: Text("Выберите клиента."))
              : DetailPanel(customer: customer, apiClient: widget.apiClient),
        ),
      ],
    )
    );
  }
}
