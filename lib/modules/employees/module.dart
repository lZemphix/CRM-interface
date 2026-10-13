import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:flutter/material.dart';

import 'widgets/create_employee.dart';
import 'widgets/archive_employee.dart';

ModuleDefinition createModule(ApiClient apiClient) => ModuleDefinition.menu(
  id: 'employees',
  title: 'Сотрудники',
  description: 'Добавление и архивирование сотрудников — формы без API',
  icon: Icons.badge_outlined,
  order: 50,
  actions: [
    ModuleAction(
      id: 'create',
      title: 'Добавить сотрудника',
      icon: Icons.person_add_alt_outlined,
      onSelected: (context) async {
        await showDialog<void>(
          context: context,
          builder: (_) => const CreateEmployeeDialog(),
        );
      },
    ),
    ModuleAction(
      id: 'archive',
      title: 'Архивировать сотрудника',
      icon: Icons.inventory_2_outlined,
      destructive: true,
      onSelected: (context) async {
        await showDialog<void>(
          context: context,
          builder: (_) => const ArchiveEmployeeDialog(),
        );
      },
    ),
  ],
);
