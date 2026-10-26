import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/di/providers.dart';
import '../core/models/auth_user.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/capture/domain/capture_result_args.dart';
import '../features/capture/presentation/capture_result_screen.dart';
import '../features/capture/presentation/encounter_screen.dart';
import '../features/capture/presentation/nfc_scan_screen.dart';
import '../features/collection/presentation/collection_screen.dart';
import '../features/collection/presentation/professor_detail_screen.dart';
import '../features/hunt/presentation/hunt_host_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/progress/presentation/completion_screen.dart';

/// Route paths (CONTRACTS §7). Use the helpers for parameterized routes.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const map = '/map';
  static const huntHost = '/hunt-host';
  static const scan = '/scan';
  static const encounterPattern = '/encounter/:encounterId';
  static const result = '/result';
  static const collection = '/collection';
  static const professorDetailPattern = '/collection/:professorId';
  static const profile = '/profile';
  static const completion = '/completion';

  static String encounter(String encounterId) => '/encounter/$encounterId';
  static String professorDetail(String professorId) =>
      '/collection/$professorId';

  /// Routes reachable without a session.
  static const Set<String> public = {splash, login, register};
}

/// Pure redirect rule (unit-testable):
/// * auth still loading → stay on / go to `/splash`
/// * signed out → `/login` (except public routes)
/// * signed in on `/splash`, `/login`, `/register` → `/map`
@visibleForTesting
String? appRedirect(AsyncValue<AuthUser?> auth, String location) {
  final resolved = auth.hasValue || auth.hasError;
  if (!resolved) return location == AppRoutes.splash ? null : AppRoutes.splash;

  final signedIn = auth.value != null;
  final isPublic = AppRoutes.public.contains(location);
  if (!signedIn) {
    if (!AppConfig.isDemoMode && location == AppRoutes.register) {
      return AppRoutes.login;
    }
    return isPublic && location != AppRoutes.splash ? null : AppRoutes.login;
  }
  if (isPublic) return AppRoutes.map;
  return null;
}

/// Notifies GoRouter whenever the auth state changes.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AsyncValue<AuthUser?>>(
      authStateProvider,
      (_, _) => notifyListeners(),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) =>
        appRedirect(ref.read(authStateProvider), state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.map,
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: AppRoutes.huntHost,
        builder: (context, state) => const HuntHostScreen(),
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (context, state) => const NfcScanScreen(),
      ),
      GoRoute(
        path: AppRoutes.encounterPattern,
        builder: (context, state) =>
            EncounterScreen(encounterId: state.pathParameters['encounterId']!),
      ),
      GoRoute(
        path: AppRoutes.result,
        // `/result` needs typed `extra`; without it (deep link, hot restart)
        // fall back to the map instead of crashing.
        redirect: (context, state) =>
            state.extra is CaptureResultArgs ? null : AppRoutes.map,
        builder: (context, state) =>
            CaptureResultScreen(args: state.extra! as CaptureResultArgs),
      ),
      GoRoute(
        path: AppRoutes.collection,
        builder: (context, state) => const CollectionScreen(),
        routes: [
          GoRoute(
            path: ':professorId',
            builder: (context, state) => ProfessorDetailScreen(
              professorId: state.pathParameters['professorId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.completion,
        builder: (context, state) => const CompletionScreen(),
      ),
    ],
  );
});
