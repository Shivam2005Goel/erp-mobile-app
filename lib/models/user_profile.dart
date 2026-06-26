/// Mirrors a row in the `final_employees` table — the table the Argmac ERP
/// uses as its profile/auth store (keyed by `auth_user_id`).
class UserProfile {
  final String id; // auth_user_id
  final String fullName;
  final String email;
  final String role;
  final DateTime createdAt;
  final String approvalStatus; // 'pending' | 'approved' | 'rejected'
  final int? employeeId;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.approvalStatus,
    this.employeeId,
  });

  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      id: (data['auth_user_id'] ?? data['id'] ?? '').toString(),
      fullName: data['full_name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: (data['role'] as String? ?? 'operations').toLowerCase(),
      approvalStatus: data['approval_status'] as String? ?? 'approved',
      employeeId: data['employee_id'] is int
          ? data['employee_id'] as int
          : int.tryParse('${data['employee_id'] ?? ''}'),
      createdAt: DateTime.tryParse(
            data['created_at'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }

  UserProfile copyWith({String? role, String? approvalStatus}) {
    return UserProfile(
      id: id,
      fullName: fullName,
      email: email,
      role: role ?? this.role,
      createdAt: createdAt,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      employeeId: employeeId,
    );
  }
}

/// A workspace department, loaded from the `departments` table. Used to
/// populate the registration role dropdown (role key = lowercased name).
class Department {
  final int id;
  final String name;
  const Department({required this.id, required this.name});

  String get roleKey => name.trim().toLowerCase();

  factory Department.fromMap(Map<String, dynamic> m) => Department(
        id: (m['department_id'] as num).toInt(),
        name: m['department_name'] as String? ?? '',
      );
}
