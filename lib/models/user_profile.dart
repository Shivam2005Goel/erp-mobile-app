class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final DateTime createdAt;
  final bool approved;
  final String password;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.approved,
    required this.password,
  });

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    DateTime? createdAt,
    bool? approved,
    String? password,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      approved: approved ?? this.approved,
      password: password ?? this.password,
    );
  }
}
