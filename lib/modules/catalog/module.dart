import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:flutter/material.dart';

ModuleDefinition createModule(ApiClient apiClient) {
  return ModuleDefinition(
    id: 'catalog',
    title: 'Каталог',
    description: 'Товары и услуги — раздел пока не реализован',
    icon: Icons.shopping_cart_outlined,
    order: 40,
    screenBuilder: (_) => const Center(child: Text('catalog')),
  );
}
