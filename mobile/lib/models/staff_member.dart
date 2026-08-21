class StaffMember {
  final String username;
  final String name;
  final String role; // "owner" | "staff"
  final String status; // "pending" | "approved"
  final String? lastLogin;

  const StaffMember({
    required this.username,
    required this.name,
    required this.role,
    required this.status,
    required this.lastLogin,
  });

  bool get isPending => status == 'pending';
  bool get isOwner => role == 'owner';

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        username: json['username'] as String,
        name: (json['name'] ?? json['username']) as String,
        role: (json['role'] ?? 'staff') as String,
        status: (json['status'] ?? 'pending') as String,
        lastLogin: json['last_login'] as String?,
      );
}
