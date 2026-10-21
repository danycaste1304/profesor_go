/// Minimal authenticated-user shape shared by the Mock and Supabase auth.
class AuthUser {
  const AuthUser({required this.id, required this.email, this.displayName});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        displayName: json['display_name'] as String?,
      );

  final String id;
  final String email;
  final String? displayName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
      };

  AuthUser copyWith({String? id, String? email, String? displayName}) =>
      AuthUser(
        id: id ?? this.id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
      );

  @override
  bool operator ==(Object other) => other is AuthUser && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AuthUser($id, $email)';
}
