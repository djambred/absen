class User {
  final String id;
  final String email;
  final String name;
  final String nip;
  final String role;
  final String? department;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.nip,
    required this.role,
    this.department,
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      nip: json['nip'],
      role: json['role'],
      department: json['department'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
