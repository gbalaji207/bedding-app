// lib/models/user_profile.dart
class UserProfile {
  final String id;
  final String? displayName;
  final String userRole;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    this.displayName,
    required this.userRole,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      displayName: json['display_name'],
      userRole: json['user_role'] ?? 'user',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
