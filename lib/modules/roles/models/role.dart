class RolePermission {
  const RolePermission({
    required this.code,
    required this.name,
    this.description,
  });
  final String code;
  final String name;
  final String? description;

  factory RolePermission.fromApi(Map<String, dynamic> data) => RolePermission(
    code: data['code'] as String,
    name: data['name'] as String,
    description: data['description'] as String?,
  );
}

class RoleInfo {
  RoleInfo({
    required this.id,
    required this.code,
    required this.name,
    required this.isSystem,
    required this.employeeCount,
    required this.version,
    required Iterable<String> permissions,
    this.description,
  }) : permissions = List.unmodifiable(permissions);
  final int id;
  final String code;
  final String name;
  final String? description;
  final bool isSystem;
  final int employeeCount;
  final int version;
  final List<String> permissions;
  bool get canDelete => !isSystem && employeeCount == 0;

  factory RoleInfo.fromApi(Map<String, dynamic> data) {
    final role = RoleInfo(
      id: data['id'] as int,
      code: data['code'] as String,
      name: data['name'] as String,
      description: data['description'] as String?,
      isSystem: data['is_system'] as bool,
      employeeCount: data['employee_count'] as int,
      version: data['version'] as int,
      permissions: List<String>.from(data['permissions'] as List),
    );
    if (role.id < 1 || role.version < 1 || role.employeeCount < 0) {
      throw const FormatException('Invalid role');
    }
    return role;
  }
}

class CreateRoleRequest {
  CreateRoleRequest({
    required this.code,
    required this.name,
    this.description,
    required Iterable<String> permissions,
  }) : permissions = List.unmodifiable(permissions);
  final String code;
  final String name;
  final String? description;
  final List<String> permissions;
  Map<String, dynamic> toApi() => {
    'code': code.trim().toLowerCase(),
    'name': name.trim(),
    'description': description == null || description!.trim().isEmpty
        ? null
        : description!.trim(),
    'permissions': permissions,
  };
}

class RoleRequestFailure implements Exception {
  const RoleRequestFailure(
    this.message, {
    this.retryAllowed = true,
    this.refreshRequired = false,
  });
  final String message;
  final bool retryAllowed;
  final bool refreshRequired;
}
