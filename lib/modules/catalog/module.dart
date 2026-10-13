import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:flutter/material.dart';

import 'repos/catalog_repository.dart';
import 'screens/catalog.dart';

ModuleDefinition createModule(ApiClient apiClient) {
  final repository = CatalogRepository(apiClient);
  return ModuleDefinition(
    id: 'catalog',
    title: 'Каталог',
    description: 'Каталог товаров и услуг',
    icon: Icons.shopping_cart_outlined,
    order: 40,
    pinnedByDefault: false,
    screenBuilder: (_) => CatalogScreen(repository: repository),
  );
}
