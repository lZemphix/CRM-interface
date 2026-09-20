import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:crm_interface/modules/customers/repos/customers_repository.dart';
import 'package:flutter/material.dart';

class EntityPanel extends StatefulWidget {
  const EntityPanel({super.key, required this.title});

  final String title;

  @override
  State<EntityPanel> createState() => _ListPanelState();
}

class _ListPanelState extends State<EntityPanel> {
  late final Future<List<Customer>> customersFuture;

  @override
  void initState() {
    super.initState();

    final apiClient = ApiClient();
    final repository = CustomersRepository(apiClient);

    customersFuture = repository.getCustomers();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20),
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
              padding: EdgeInsets.symmetric(vertical: 20),
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
      children: [
        titleArea(),
        TextField(
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: "Поиск",
          ),
        ),
        Row(
          children: [
            filterButton("Все"),
            filterButton("Мои"),
            filterButton("Без ответственного"),
          ],
        ),
      ],
    );
  }

  Widget customerButton({
    IconData? photo,
    required String fullName,
    phoneNumber,
    required String lastVisit,
  }) {
    return Row(
      children: [
        Icon(photo),
        Column(children: [Text(fullName), Text(phoneNumber)]),
        Text(lastVisit),
      ],
    );
  }

  Widget addCostumerButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.activeElement,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Text("+"),
    );
  }

  Widget titleArea() {
    return Row(children: [Text(widget.title), addCostumerButton()]);
  }

  Widget filterButton(String text) {
    return InkWell(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.notActiveBorder, width: 1),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Text(text),
      ),
    );
  }

  Widget customersList() {
    return FutureBuilder<List<Customer>>(
      future: customersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final customers = snapshot.data ?? [];

        if (customers.isEmpty) {
          return const Center(child: Text("Клиентов не найдено"));
        }

        return ListView.builder(
          itemCount: customers.length,
          itemBuilder: ((context, index) {
            final customer = customers[index];
            return Container(
              padding: EdgeInsets.symmetric(vertical: 5),
              child: customerButton(
                photo: Icons.people,
                fullName: customer.fullName,
                phoneNumber: customer.primaryContact,
                lastVisit: "never",
              ),
            ); // TODO: Исправить
          }),
        );
      },
    );
  }
}
