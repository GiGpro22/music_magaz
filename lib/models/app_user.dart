import 'role.dart';

class AppUser {
  final String id;
  final String email;
  final String name;
  final Role role;
  final String? customerId;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.customerId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? json['email'] as String? ?? '',
      role: Role.fromString(json['role'] as String?),
      customerId: _relId(json['customer']),
    );
  }

  static String? _relId(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) return value['id'] as String?;
    return null;
  }
}
