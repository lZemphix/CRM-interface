class AuthProfile {
  const AuthProfile({
    required this.id,
    required this.login,
    required this.fullName,
    required this.roleName,
  });

  final int id;
  final String login;
  final String fullName;
  final String roleName;

  factory AuthProfile.fromApi(Map<String, dynamic> data) {
    final role = data['role'] as Map;
    return AuthProfile(
      id: data['id'] as int,
      login: data['login'] as String,
      fullName: data['full_name'] as String,
      roleName: role['name'] as String,
    );
  }

  String get displayName => fullName.trim().isEmpty ? login : fullName.trim();
}
