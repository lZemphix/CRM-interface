import 'package:crm_interface/modules/customers/widgets/detail_panel.dart';
import 'package:crm_interface/modules/customers/widgets/entity_panel.dart';
import 'package:flutter/material.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 350, child: EntityPanel(title: "Клиенты")),
        Expanded(child: DetailPanel()),
      ],
    );
  }
}
