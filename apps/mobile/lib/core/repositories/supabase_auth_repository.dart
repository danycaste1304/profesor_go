import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../errors/app_exception.dart';
import '../models/auth_user.dart';
import '../models/profile.dart';
import 'auth_repository.dart';

/// [AuthRepository] over Supabase Auth + the `profiles` table.
///
/// Uses Google OAuth in the public build. The `auth.users` trigger writes the
/// corresponding `profiles` row (CONTRACTS §2).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AuthUser?> authState() async* {
    yield currentUser;
    yield* _client.auth.onAuthStateChange
        .map((state) => _toAuthUser(state.session?.user))
        .distinct((a, b) => a?.id == b?.id && a?.displayName == b?.displayName);
  }

  @override
  AuthUser? get currentUser => _toAuthUser(_client.auth.currentUser);

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'profesorgo://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw AppException.fromCode(AppException.serverUnavailable);
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }

  @override
  Future<void> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final name = displayName?.trim();
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {if (name != null && name.isNotEmpty) 'display_name': name},
      );
      final user = response.user;
      if (user == null) {
        // No user and no session: nothing usable came back.
        if (response.session == null) {
          throw AppException.fromCode(AppException.serverUnavailable);
        }
        return;
      }
      // With e-mail confirmation enabled GoTrue does not report a duplicate
      // sign-up as an error (user enumeration protection): it returns an
      // obfuscated user with an empty `identities` list instead.
      if ((user.identities ?? const []).isEmpty && response.session == null) {
        throw AppException.fromCode(AppException.emailTaken);
      }
      // `response.session == null` with a real user means the account was
      // created but needs e-mail confirmation. The caller (AuthController)
      // notices `currentUser == null` and explains the next step.
    } catch (e) {
      throw AppException.from(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  @override
  Future<Profile?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) {
        // Trigger may lag right after sign-up: synthesize from the auth user.
        return Profile(
          id: user.id,
          email: user.email ?? '',
          displayName: _displayName(user),
        );
      }
      return Profile.fromJson(row);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  static AuthUser? _toAuthUser(User? user) {
    if (user == null) return null;
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      displayName: _displayName(user),
    );
  }

  static String? _displayName(User user) {
    final metadata = user.userMetadata;
    for (final key in ['display_name', 'full_name', 'name']) {
      final value = metadata?[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
