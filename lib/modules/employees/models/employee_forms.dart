/// Presentation data only. No API paths, JSON schemas or synthetic accounts.
class EmployeeRoleChoice {
  const EmployeeRoleChoice({
    required this.id,
    required this.name,
    this.description = '',
  });
  final int id;
  final String name;
  final String description;
}

class EmployeeBranchChoice {
  const EmployeeBranchChoice({required this.id, required this.name});
  final int id;
  final String name;
}

class EmployeeCreateDraft {
  EmployeeCreateDraft({
    required this.fullName,
    required this.login,
    required this.roleId,
    required Iterable<int> branchIds,
    this.primaryBranchId,
  }) : branchIds = List.unmodifiable(branchIds);

  final String fullName;
  final String login;
  final int roleId;
  final List<int> branchIds;
  final int? primaryBranchId;
}

class EmployeeCreatedView {
  const EmployeeCreatedView({
    required this.fullName,
    required this.login,
    required this.temporaryPassword,
  });
  final String fullName;
  final String login;
  final String temporaryPassword;
}

class EmployeeArchiveView {
  const EmployeeArchiveView({
    required this.id,
    required this.fullName,
    required this.login,
    required this.roleName,
    required this.openTasks,
    required this.version,
  });

  final int id;
  final String fullName;
  final String login;
  final String roleName;
  final int openTasks;
  final int version;
}

/// The future API adapter may map recoverable failures without coupling UI to Dio.
class EmployeeFormFailure implements Exception {
  const EmployeeFormFailure(this.message, {this.retryAllowed = true});
  final String message;
  final bool retryAllowed;
}

String? validateEmployeeLogin(String? value) {
  final login = value?.trim() ?? '';
  if (login.isEmpty) return 'Укажите логин';
  if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{2,127}$').hasMatch(login)) {
    return 'От 3 до 128 символов: латиница, цифры, точка, дефис, _';
  }
  return null;
}
