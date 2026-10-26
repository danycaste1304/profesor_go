import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../config/app_config.dart';
import '../config/campus_config.dart';
import '../hunt/hunt_service.dart';
import '../location/location_service.dart';
import '../location/mock_location_service.dart';
import '../location/real_location_service.dart';
import '../mock/demo_game_state.dart';
import '../models/auth_user.dart';
import '../models/capture.dart';
import '../models/collection_progress.dart';
import '../models/professor.dart';
import '../models/profile.dart';
import '../nfc/mock_nfc_service.dart';
import '../nfc/nfc_service.dart';
import '../nfc/real_nfc_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/capture_service.dart';
import '../repositories/mock_auth_repository.dart';
import '../repositories/mock_capture_service.dart';
import '../repositories/mock_professor_repository.dart';
import '../repositories/professor_repository.dart';
import '../repositories/supabase_auth_repository.dart';
import '../repositories/supabase_capture_service.dart';
import '../repositories/supabase_professor_repository.dart';

// ---------------------------------------------------------------------------
// Infrastructure. Mock vs Supabase is decided by AppConfig.isDemoMode.
// Feature code must depend on the abstract types only.
// ---------------------------------------------------------------------------

/// Shared in-memory game state for demo mode (professors, tags, captures).
final demoGameStateProvider = Provider<DemoGameState>(
  (ref) => DemoGameState(persist: true),
);

/// The Supabase client. Only valid when `AppConfig.isDemoMode == false`
/// (main.dart initializes Supabase before the first read).
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final nfcServiceProvider = Provider<NfcService>((ref) {
  if (AppConfig.isDemoMode) {
    return MockNfcService();
  }
  return RealNfcService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  if (AppConfig.isDemoMode) {
    final service = MockLocationService(
      stepInterval: CampusConfig.demoStepInterval,
    );
    ref.onDispose(service.dispose);
    return service;
  }
  return RealLocationService();
});

final professorRepositoryProvider = Provider<ProfessorRepository>((ref) {
  if (AppConfig.isDemoMode) {
    return MockProfessorRepository(ref.watch(demoGameStateProvider));
  }
  return SupabaseProfessorRepository(ref.watch(supabaseClientProvider));
});

final captureServiceProvider = Provider<CaptureService>((ref) {
  if (AppConfig.isDemoMode) {
    return MockCaptureService(ref.watch(demoGameStateProvider));
  }
  return SupabaseCaptureService(ref.watch(supabaseClientProvider));
});

/// Campus hunt exists only in the real backend build. Demo screens never read
/// this provider, so they still work without a Supabase client.
final huntServiceProvider = Provider<HuntService>(
  (ref) => SupabaseHuntService(ref.watch(supabaseClientProvider)),
);

final huntPublisherProvider = FutureProvider<HuntPublisher?>((ref) {
  if (AppConfig.isDemoMode) return Future<HuntPublisher?>.value();
  ref.watch(authStateProvider);
  return ref.watch(huntServiceProvider).myPublisher();
});

final activeHuntsProvider = FutureProvider<List<HuntSession>>((ref) {
  if (AppConfig.isDemoMode) return Future.value(const []);
  ref.watch(authStateProvider);
  return ref.watch(huntServiceProvider).activeSessions();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.isDemoMode) {
    final repo = MockAuthRepository(
      persist: true,
      gameState: ref.watch(demoGameStateProvider),
    );
    ref.onDispose(repo.dispose);
    return repo;
  }
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

// ---------------------------------------------------------------------------
// Connectivity
// ---------------------------------------------------------------------------

/// `true` while the device reports some network. Always `true` in demo mode.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  if (AppConfig.isDemoMode) {
    yield true;
    return;
  }
  final connectivity = Connectivity();
  yield _isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_isOnline);
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// Synchronous convenience over [connectivityProvider] (optimistic `true`
/// until the first event).
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).value ?? true,
);

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

/// Current user; `null` when signed out. Loading until the first event.
final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authState(),
);

/// Synchronous current user (null while loading or signed out).
final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(authStateProvider).value,
);

/// The `profiles` row of the signed-in user. Re-fetched on auth changes.
final profileProvider = FutureProvider<Profile?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).getProfile();
});

// ---------------------------------------------------------------------------
// Collection data
// ---------------------------------------------------------------------------

final professorsProvider = FutureProvider<List<Professor>>(
  (ref) => ref.watch(professorRepositoryProvider).getActiveProfessors(),
);

final myCapturesProvider = FutureProvider<List<Capture>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(professorRepositoryProvider).getMyCaptures();
});

final collectionProgressProvider = FutureProvider<CollectionProgress>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(professorRepositoryProvider).getProgress();
});

/// Set of captured professor ids, derived from [myCapturesProvider].
final capturedIdsProvider = Provider<Set<String>>((ref) {
  final captures = ref.watch(myCapturesProvider).value ?? const <Capture>[];
  return captures.map((c) => c.professorId).toSet();
});

/// Refreshes every collection-related provider (call after a capture or a
/// pull-to-refresh) from a widget.
void invalidateCollection(WidgetRef ref) =>
    _invalidateCollection(ref.invalidate);

/// Same as [invalidateCollection], from inside a provider / notifier.
void invalidateCollectionFromProvider(Ref ref) =>
    _invalidateCollection(ref.invalidate);

void _invalidateCollection(
  void Function(FutureProvider<Object?> provider) invalidate,
) {
  invalidate(professorsProvider);
  invalidate(myCapturesProvider);
  invalidate(collectionProgressProvider);
  invalidate(profileProvider);
}
