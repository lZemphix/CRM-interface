import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:flutter/material.dart';

import 'screens/customers.dart';

ModuleDefinition createModule(ApiClient apiClient) {
  return ModuleDefinition(
    id: 'customers',
    title: 'Клиенты',
    description: 'Карточки клиентов, заметки и история активности',
    icon: Icons.badge_outlined,
    order: 10,
    screenBuilder: (_) => CustomersScreen(apiClient: apiClient),
  );
}
