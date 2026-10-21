import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  runApp(const ProviderScope(child: App()));
}

/// Initializes Supabase when not in demo mode. Falls back to demo mode (with
/// a log line) when credentials are missing or initialization fails, so the
/// app always starts.
@visibleForTesting
Future<void> bootstrap() async {
  if (AppConfig.isDemoMode) {
    debugPrint('[ProfesorGO] DEMO_MODE=true: using in-memory mock services.');
    return;
  }
  if (!AppConfig.hasSupabaseCredentials) {
    AppConfig.forceDemoMode('SUPABASE_URL / SUPABASE_ANON_KEY not provided');
    debugPrint(
      '[ProfesorGO] DEMO_MODE=false but SUPABASE_URL / SUPABASE_ANON_KEY are '
      'missing. Falling back to demo mode. Run with '
      '--dart-define-from-file=.env to use the real backend.',
    );
    return;
  }
  // A trailing slash would produce `…//rest/v1` once SupabaseClient appends
  // its paths, which PostgREST rejects.
  final url = AppConfig.supabaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  try {
    // supabase_flutter 2.17.2: `publishableKey` replaced the now-deprecated
    // `anonKey`; both feed the same client key. `Supabase.initialize` also
    // wires SharedPreferences-backed session + PKCE storage, which is why the
    // live test builds its own SupabaseClient instead (see test/live/).
    await Supabase.initialize(
      url: url,
      publishableKey: AppConfig.supabaseAnonKey.trim(),
      debug: kDebugMode,
    );
    debugPrint('[ProfesorGO] Supabase initialized ($url).');
  } catch (e) {
    AppConfig.forceDemoMode('Supabase.initialize failed: $e');
    debugPrint(
      '[ProfesorGO] Supabase.initialize failed ($e). Falling back to demo mode.',
    );
  }
}
