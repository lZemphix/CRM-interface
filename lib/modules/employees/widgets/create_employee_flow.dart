import 'package:flutter/material.dart';

import '../models/employee_forms.dart';
import '../repos/employees_repository.dart';
import 'create_employee.dart';
import 'dialog_frame.dart';

class CreateEmployeeFlow extends StatefulWidget {
  const CreateEmployeeFlow({
    super.key,
    required this.repository,
    required this.onCreate,
    this.onCreateRole,
  });
  final EmployeesRepository repository;
  final Future<EmployeeCreatedView> Function(EmployeeCreateDraft) onCreate;
  final Future<EmployeeRoleChoice?> Function()? onCreateRole;

  @override
  State<CreateEmployeeFlow> createState() => _CreateEmployeeFlowState();
}

class _CreateEmployeeFlowState extends State<CreateEmployeeFlow> {
  late Future<EmployeeFormOptions> _options;
  @override
  void initState() {
    super.initState();
    _options = widget.repository.getFormOptions();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<EmployeeFormOptions>(
    future: _options,
    builder: (context, snapshot) {
      final options = snapshot.data;
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          options != null) {
        return CreateEmployeeDialog(
          roles: options.roles,
          branches: options.branches,
          onCreate: widget.onCreate,
          onCreateRole: widget.onCreateRole,
        );
      }
      final error = snapshot.connectionState == ConnectionState.done
          ? snapshot.error
          : null;
      return EmployeeDialogFrame(
        title: 'Новый сотрудник',
        description: 'Загрузка ролей и филиалов',
        icon: Icons.person_add_alt_outlined,
        body: error == null
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : EmployeeFormError(
                error is EmployeeFormFailure
                    ? error.message
                    : 'Не удалось загрузить справочники.',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          if (error != null)
            FilledButton(
              onPressed: () {
                final options = widget.repository.getFormOptions();
                setState(() {
                  _options = options;
                });
              },
              child: const Text('Повторить'),
            ),
        ],
      );
    },
  );
}
