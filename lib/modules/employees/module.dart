import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:crm_interface/core/modules/module_data_changes.dart';
import 'package:flutter/material.dart';

import '../roles/roles.dart';

import 'repos/employees_repository.dart';
import 'models/employee_forms.dart';
import 'widgets/create_employee_flow.dart';
import 'widgets/archive_employee.dart';

ModuleDefinition createModule(ApiClient apiClient) {
  final repository = EmployeesRepository(apiClient);
  return ModuleDefinition.menu(
    id: 'employees',
    title: 'Сотрудники',
    description: 'Добавление и архивирование сотрудников',
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
            barrierDismissible: false,
            builder: (_) => CreateEmployeeFlow(
              repository: repository,
              onCreateRole: () async {
                final role = await showCreateRoleDialog(context, apiClient);
                return role == null
                    ? null
                    : EmployeeRoleChoice(
                        id: role.id,
                        name: role.name,
                        description:
                            role.description ??
                            'Разрешений в роли: ${role.permissions.length}. Доступ проверяется сервером.',
                      );
              },
              onCreate: (draft) async {
                final result = await repository.create(draft);
                if (context.mounted) {
                  const ModuleDataChanged().dispatch(context);
                }
                return result;
              },
            ),
          );
        },
      ),
      ModuleAction(
        id: 'archive',
        title: 'Архивировать сотрудника',
        icon: Icons.inventory_2_outlined,
        destructive: true,
        onSelected: (context) async {
          final messenger = ScaffoldMessenger.of(context);
          final archived = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => ArchiveEmployeeDialog(
              onLookup: repository.findByLogin,
              onArchive: (employee) async {
                try {
                  await repository.deactivate(employee);
                } on EmployeeFormFailure catch (error) {
                  // The server may have applied an unconfirmed command.
                  if (error.refreshRequired && context.mounted) {
                    const ModuleDataChanged().dispatch(context);
                  }
                  rethrow;
                }
                if (context.mounted) {
                  const ModuleDataChanged().dispatch(context);
                }
              },
            ),
          );
          if (archived == true && messenger.mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Сотрудник архивирован. Открытые задачи остались без ответственного.',
                ),
              ),
            );
          }
        },
      ),
    ],
  );
}
