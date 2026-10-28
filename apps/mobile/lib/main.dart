import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/qr/pending_qr.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await bootstrap();
    runApp(const ProviderScope(child: App()));
  } catch (error) {
    debugPrint('[ProfesorGO] Startup failed: $error');
    runApp(const _StartupErrorApp());
  }
}

/// Initializes Supabase when not in demo mode. Misconfigured real builds fail
/// closed and show a setup error instead of allowing mock captures.
@visibleForTesting
Future<void> bootstrap() async {
  await PendingQr.initialize();
  if (AppConfig.isDemoMode) {
    debugPrint('[ProfesorGO] DEMO_MODE=true: using in-memory mock services.');
    return;
  }
  final configurationError = AppConfig.validateBackendConfiguration(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    releaseMode: kReleaseMode,
  );
  if (configurationError != null) throw StateError(configurationError);
  // A trailing slash would produce `…//rest/v1` once SupabaseClient appends
  // its paths, which PostgREST rejects.
  final url = AppConfig.supabaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
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
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 56),
                SizedBox(height: 16),
                Text(
                  'No se pudo iniciar Profesor GO',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'La configuración del servidor no está lista. Contacta al equipo del proyecto.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
