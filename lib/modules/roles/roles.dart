/// Public integration surface; callers do not import role widgets/repositories.
library;

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/modules/module_data_changes.dart';
import 'package:flutter/material.dart';

import 'models/role.dart';
import 'repos/roles_repository.dart';
import 'widgets/create_role.dart';
import 'widgets/delete_role.dart';

export 'models/role.dart' show RoleInfo;

Future<RoleInfo?> showCreateRoleDialog(
  BuildContext context,
  ApiClient apiClient,
) async {
  final role = await showDialog<RoleInfo>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CreateRoleDialog(repository: RolesRepository(apiClient)),
  );
  if (role != null && context.mounted) {
    const ModuleDataChanged().dispatch(context);
  }
  return role;
}

Future<void> showDeleteRoleDialog(
  BuildContext context,
  ApiClient apiClient,
) async {
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DeleteRoleDialog(repository: RolesRepository(apiClient)),
  );
  if (deleted == true && context.mounted) {
    const ModuleDataChanged().dispatch(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Роль удалена')));
  }
}
