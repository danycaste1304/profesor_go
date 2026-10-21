import 'package:flutter/foundation.dart';

/// Compile-time configuration, injected with `--dart-define` /
/// `--dart-define-from-file=.env` (see CONTRACTS §6).
///
/// `DEMO_MODE` defaults to `true`, so a plain `flutter run` works without any
/// backend. `main.dart` may force demo mode at runtime when the Supabase
/// credentials are missing or initialization fails.
abstract final class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String _demoModeRaw = String.fromEnvironment(
    'DEMO_MODE',
    defaultValue: 'true',
  );

  /// Minimum password length the backend accepts, pinned to
  /// `supabase/config.toml` → `[auth] minimum_password_length`.
  ///
  /// The client must never accept fewer characters than the server: a shorter
  /// password would pass the form and then be rejected by GoTrue with
  /// `weak_password`, leaving the player with an error that asks for exactly
  /// what they already typed. Every Spanish string that names the minimum is
  /// built from this constant (see `AuthValidators` and
  /// `AppException.messages`), so the number can only ever be changed here.
  static const int minPasswordLength = 8;

  /// Value of the `DEMO_MODE` define as compiled.
  static bool get compiledDemoMode =>
      _demoModeRaw.trim().toLowerCase() != 'false';

  static bool? _runtimeOverride;
  static String? _fallbackReason;

  /// True when the app must run fully in memory with the Mock services.
  static bool get isDemoMode => _runtimeOverride ?? compiledDemoMode;

  /// True when Supabase credentials were provided at compile time.
  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Why the app fell back to demo mode at runtime (null if it did not).
  static String? get demoFallbackReason => _fallbackReason;

  /// Forces demo mode at runtime (used by `main.dart` when the backend cannot
  /// be initialized). Must be called before any provider is created.
  static void forceDemoMode(String reason) {
    _runtimeOverride = true;
    _fallbackReason = reason;
  }

  /// Developer-only tooling is shown only in debug builds. The demo tag
  /// picker and confirmed Profedex reset are available in every demo build.
  static bool get debugToolsEnabled => kDebugMode;

  /// Visible for tests: clears the runtime override.
  @visibleForTesting
  static void resetRuntimeOverride() {
    _runtimeOverride = null;
    _fallbackReason = null;
  }
}
