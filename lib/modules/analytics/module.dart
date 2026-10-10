import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:flutter/material.dart';

ModuleDefinition createModule(ApiClient apiClient) {
  return ModuleDefinition(
    id: 'analytics',
    title: 'Аналитика',
    description: 'Дашборды — раздел пока не реализован',
    icon: Icons.analytics_outlined,
    order: 30,
    screenBuilder: (_) => const Center(child: Text('analytics')),
  );
}
