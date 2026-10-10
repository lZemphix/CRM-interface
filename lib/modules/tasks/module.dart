import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:flutter/material.dart';

import 'repos/tasks.dart';
import 'screens/tasks.dart';

ModuleDefinition createModule(ApiClient apiClient) {
  final repository = TasksRepository(apiClient);
  return ModuleDefinition(
    id: 'tasks',
    title: 'Задачи',
    description: 'Канбан, исполнители и подзадачи',
    icon: Icons.task_alt_outlined,
    order: 20,
    screenBuilder: (_) => TasksScreen(tasksRepository: repository),
  );
}
