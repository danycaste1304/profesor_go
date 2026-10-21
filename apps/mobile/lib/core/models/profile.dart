/// `profiles.role` (CONTRACTS §1).
enum UserRole {
  player('player'),
  admin('admin');

  const UserRole(this.wireValue);
  final String wireValue;

  static UserRole parse(String? value) => value?.trim().toLowerCase() == 'admin'
      ? UserRole.admin
      : UserRole.player;
}

/// Row of `public.profiles` (CONTRACTS §2).
class Profile {
  const Profile({
    required this.id,
    required this.email,
    this.displayName,
    this.role = UserRole.player,
    this.createdAt,
    this.collectionCompletedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        displayName: json['display_name'] as String?,
        role: UserRole.parse(json['role'] as String?),
        createdAt: json['created_at'] is String
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        collectionCompletedAt: json['collection_completed_at'] is String
            ? DateTime.tryParse(json['collection_completed_at'] as String)
            : null,
      );

  final String id;
  final String email;
  final String? displayName;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? collectionCompletedAt;

  /// Name to show in the UI (falls back to the e-mail local part).
  String get nameOrEmail {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  bool get hasCompletedCollection => collectionCompletedAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'role': role.wireValue,
        'created_at': createdAt?.toIso8601String(),
        'collection_completed_at': collectionCompletedAt?.toIso8601String(),
      };

  Profile copyWith({
    String? id,
    String? email,
    String? displayName,
    UserRole? role,
    DateTime? createdAt,
    DateTime? collectionCompletedAt,
  }) =>
      Profile(
        id: id ?? this.id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        createdAt: createdAt ?? this.createdAt,
        collectionCompletedAt:
            collectionCompletedAt ?? this.collectionCompletedAt,
      );

  @override
  bool operator ==(Object other) => other is Profile && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Profile($id, $email, ${role.wireValue})';
}
