import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/di/providers.dart';
import '../../../core/errors/app_exception.dart';

/// UI state of the auth forms: one operation at a time, a user-facing
/// Spanish [error] and an optional informational [notice].
class AuthFormState {
  const AuthFormState({this.loading = false, this.error, this.notice});

  final bool loading;
  final String? error;
  final String? notice;

  bool get hasError => error != null;
  bool get hasNotice => notice != null;

  @override
  bool operator ==(Object other) =>
      other is AuthFormState &&
      other.loading == loading &&
      other.error == error &&
      other.notice == notice;

  @override
  int get hashCode => Object.hash(loading, error, notice);

  @override
  String toString() =>
      'AuthFormState(loading: $loading, error: $error, notice: $notice)';
}

final authControllerProvider = NotifierProvider<AuthController, AuthFormState>(
  AuthController.new,
);

/// Runs sign-in / sign-up / sign-out against [authRepositoryProvider] and
/// exposes `{loading, error}` to the screens. Navigation is never done here:
/// the router reacts to the auth stream.
class AuthController extends Notifier<AuthFormState> {
  static const String noInternetMessage =
      'Sin conexión. Comprueba tu internet e inténtalo de nuevo.';
  static const String emailConfirmationMessage =
      'Cuenta creada. Confirma tu correo con el enlace que te hemos enviado '
      'y después inicia sesión.';

  @override
  AuthFormState build() => const AuthFormState();

  /// Returns `true` on success. On failure [AuthFormState.error] is set.
  Future<bool> signIn(String email, String password) => _run(
    () => ref.read(authRepositoryProvider).signIn(email.trim(), password),
  );

  Future<bool> signInWithGoogle() async {
    final started = await _run(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
    if (started &&
        ref.mounted &&
        ref.read(authRepositoryProvider).currentUser == null) {
      state = const AuthFormState(
        notice: 'Completa el acceso en Google y vuelve a Profesor GO.',
      );
    }
    return started;
  }

  /// Creates the account and leaves the user signed in. When the backend
  /// returns no session (e-mail confirmation enabled) a regular sign-in is
  /// attempted; if that is rejected because the e-mail is not confirmed the
  /// call still succeeds and [AuthFormState.notice] explains the next step.
  Future<bool> signUp(String email, String password, {String? displayName}) =>
      _run(() async {
        final repo = ref.read(authRepositoryProvider);
        final trimmedEmail = email.trim();
        final name = displayName?.trim();
        await repo.signUp(
          trimmedEmail,
          password,
          displayName: name == null || name.isEmpty ? null : name,
        );
        if (repo.currentUser != null) return;
        try {
          await repo.signIn(trimmedEmail, password);
        } on AppException catch (e) {
          if (_needsEmailConfirmation(e)) {
            throw const _EmailConfirmationPending();
          }
          rethrow;
        }
      });

  Future<bool> signOut() =>
      _run(() => ref.read(authRepositoryProvider).signOut());

  /// Hides the current error / notice (e.g. when the user dismisses the
  /// banner or switches between login and register).
  void clearMessages() {
    if (state.hasError || state.hasNotice) {
      state = AuthFormState(loading: state.loading);
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (state.loading) return false;
    if (!ref.read(isOnlineProvider)) {
      state = const AuthFormState(error: noInternetMessage);
      return false;
    }
    state = const AuthFormState(loading: true);
    try {
      await action();
      if (ref.mounted) state = const AuthFormState();
      return true;
    } on _EmailConfirmationPending {
      if (ref.mounted) {
        state = const AuthFormState(notice: emailConfirmationMessage);
      }
      return true;
    } catch (e) {
      if (ref.mounted) state = AuthFormState(error: messageFor(e));
      return false;
    }
  }

  /// Spanish message for any error (never a stack trace). Network failures
  /// get an auth-specific wording instead of the capture-oriented default.
  static String messageFor(Object error) {
    final e = AppException.from(error);
    return e.isNoInternet ? noInternetMessage : e.message;
  }

  static bool _needsEmailConfirmation(AppException e) {
    final cause = e.cause;
    if (cause is! AuthException) return false;
    return cause.code == 'email_not_confirmed' ||
        cause.message.toLowerCase().contains('not confirmed');
  }
}

class _EmailConfirmationPending implements Exception {
  const _EmailConfirmationPending();
}
