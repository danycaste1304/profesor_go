import 'package:flutter/foundation.dart';

/// Compile-time configuration, injected with `--dart-define` /
/// `--dart-define-from-file=.env` (see CONTRACTS §6).
///
/// `DEMO_MODE` defaults to `true`, so a plain `flutter run` works without any
/// backend. A build explicitly configured with `DEMO_MODE=false` never switches
/// to mock services at runtime.
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

  /// True when the app must run fully in memory with the Mock services.
  static bool get isDemoMode => compiledDemoMode;

  /// Returns a setup error before initializing the real backend. Release
  /// builds must use HTTPS; debug builds can use local Supabase over HTTP.
  static String? validateBackendConfiguration({
    required String url,
    required String anonKey,
    required bool releaseMode,
  }) {
    if (url.trim().isEmpty || anonKey.trim().isEmpty) {
      return 'Faltan SUPABASE_URL o SUPABASE_ANON_KEY.';
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return 'SUPABASE_URL no es una URL HTTP válida.';
    }
    if (releaseMode && uri.scheme != 'https') {
      return 'La compilación de producción requiere SUPABASE_URL con HTTPS.';
    }
    return null;
  }

  /// Developer-only tooling is shown only in debug builds. The demo tag
  /// picker and confirmed Profedex reset are available in every demo build.
  static bool get debugToolsEnabled => kDebugMode;
}
