import '../models/auth_user.dart';
import '../models/profile.dart';

/// Authentication + own profile.
abstract class AuthRepository {
  /// Emits the current user immediately, then every change (null = signed out).
  Stream<AuthUser?> authState();

  Future<void> signIn(String email, String password);

  /// Starts Google OAuth. The session arrives later through [authState].
  Future<void> signInWithGoogle();

  Future<void> signUp(String email, String password, {String? displayName});

  Future<void> signOut();

  AuthUser? get currentUser;

  /// The `profiles` row of the current user (null when signed out).
  Future<Profile?> getProfile();
}
