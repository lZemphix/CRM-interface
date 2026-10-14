import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:flutter/material.dart';

import 'roles.dart';

ModuleDefinition createModule(ApiClient apiClient) => ModuleDefinition.menu(
  id: 'roles',
  title: 'Роли',
  description: 'Наборы прав сотрудников',
  icon: Icons.admin_panel_settings_outlined,
  order: 60,
  actions: [
    ModuleAction(
      id: 'create',
      title: 'Добавить роль',
      icon: Icons.add_moderator_outlined,
      onSelected: (context) async {
        final role = await showCreateRoleDialog(context, apiClient);
        if (role != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Роль «${role.name}» создана')),
          );
        }
      },
    ),
    ModuleAction(
      id: 'delete',
      title: 'Удалить роль',
      icon: Icons.delete_outline,
      destructive: true,
      onSelected: (context) => showDeleteRoleDialog(context, apiClient),
    ),
  ],
);
