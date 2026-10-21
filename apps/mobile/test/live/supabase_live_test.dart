@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/repositories/professor_repository.dart';
import 'package:profesor_go/core/repositories/supabase_auth_repository.dart';
import 'package:profesor_go/core/repositories/supabase_capture_service.dart';
import 'package:profesor_go/core/repositories/supabase_professor_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

/// Opt-in end-to-end test of the Supabase layer against a **running** backend.
///
/// It exercises the real repository classes (`SupabaseProfessorRepository`,
/// `SupabaseCaptureService`, `SupabaseAuthRepository`) over real HTTP, with no
/// device and no emulator.
///
/// Three things are needed to make that work under `flutter test`:
///  1. `HttpOverrides.global = null` — `TestWidgetsFlutterBinding` installs a
///     mock `HttpClient` that answers **every** request with `400` and an
///     empty body, which would otherwise make each call look like
///     `INVALID_INPUT`. Clearing the override restores real sockets.
///  2. A plain [SupabaseClient] instead of `Supabase.initialize()`, which
///     registers platform channels (deep links, secure storage) that do not
///     exist in the test host. It is the very same object the providers in
///     `lib/core/di/providers.dart` hand to the repositories.
///  3. A `pkceAsyncStorage` for the client (in the app `Supabase.initialize`
///     injects `SharedPreferencesGotrueAsyncStorage`; without one gotrue
///     asserts on the PKCE flow) and
///     `SharedPreferences.setMockInitialValues` for [ProfessorCache].
///
/// Skips itself unless the backend is pointed at explicitly:
///
/// ```bash
/// flutter test test/live/supabase_live_test.dart \
///   --dart-define=SUPABASE_LIVE_URL=http://127.0.0.1:54321 \
///   --dart-define=SUPABASE_LIVE_ANON_KEY=<anon key> \
///   --dart-define=SUPABASE_LIVE_SERVICE_KEY=<service_role key>
/// ```
///
/// `SUPABASE_LIVE_SERVICE_KEY` is optional and only used to delete the
/// throw-away user this test signs up; without it the user is left behind and
/// the test prints a note naming it.
const String _liveUrl = String.fromEnvironment('SUPABASE_LIVE_URL');
const String _liveAnonKey = String.fromEnvironment('SUPABASE_LIVE_ANON_KEY');
const String _liveServiceKey = String.fromEnvironment(
  'SUPABASE_LIVE_SERVICE_KEY',
);

/// Tag of the seeded professor #1 (Prof. Henry, COMMON, base rate 0.80).
/// COMMON 0.80 + EXCELLENT bonus 0.20 => p = 1.0, so the capture is
/// deterministic; MISS forces p = 0 and always fails (CONTRACTS §9).
const String _seedTag = 'DEMO-TAG-01';
const String _seedProfessorId = '00000000-0000-4000-8000-000000000016';

/// The fixed ids of the 10 seeded professors (CONTRACTS §5).
const List<String> _seedProfessorIds = [
  '00000000-0000-4000-8000-000000000016',
  '00000000-0000-4000-8000-000000000015',
  '00000000-0000-4000-8000-000000000014',
  '00000000-0000-4000-8000-000000000013',
  '00000000-0000-4000-8000-000000000012',
  '00000000-0000-4000-8000-000000000011',
  '00000000-0000-4000-8000-000000000009',
  '00000000-0000-4000-8000-000000000010',
  '00000000-0000-4000-8000-000000000017',
  '00000000-0000-4000-8000-000000000018',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final configured = _liveUrl.isNotEmpty && _liveAnonKey.isNotEmpty;

  group(
    'Supabase live backend',
    () {
      late SupabaseClient client;
      late SupabaseAuthRepository auth;
      late SupabaseProfessorRepository professors;
      late SupabaseCaptureService captures;
      late String email;
      String? userId;

      /// Number of active professors this run saw (>= the 10 seeded ones).
      var totalProfessors = 10;

      setUpAll(() async {
        // flutter_test answers every HTTP request with an empty 400 unless the
        // override is cleared. This test is explicitly about real traffic.
        HttpOverrides.global = null;
        SharedPreferences.setMockInitialValues(<String, Object>{});
        client = SupabaseClient(
          _liveUrl,
          _liveAnonKey,
          authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryPkceStore()),
        );
        auth = SupabaseAuthRepository(client);
        professors = SupabaseProfessorRepository(
          client,
          cache: ProfessorCache(persistent: false),
        );
        captures = SupabaseCaptureService(client);
        email = 'live-${DateTime.now().microsecondsSinceEpoch}@profesorgo.test';
      });

      tearDownAll(() async {
        final id = userId;
        try {
          await auth.signOut();
        } catch (_) {
          // Signing out is best effort; the user still has to go.
        }
        if (id != null) {
          if (_liveServiceKey.isEmpty) {
            // ignore: avoid_print
            print(
              'NOTE: SUPABASE_LIVE_SERVICE_KEY not set — the test user $email '
              '($id) was NOT deleted. Re-run with the service-role key, or '
              'delete it manually: '
              "delete from auth.users where id = '$id';",
            );
          } else {
            await _deleteUser(id);
          }
        }
        await client.dispose();
      });

      test('signs up a fresh user and reads the profile', () async {
        await auth.signUp(email, 'livepass12345', displayName: 'Live Tester');
        final user = auth.currentUser;
        expect(user, isNotNull, reason: 'sign-up must return a session');
        userId = user!.id;
        expect(user.email, email);
        expect(user.displayName, 'Live Tester');

        final profile = await auth.getProfile();
        expect(profile, isNotNull);
        expect(profile!.id, user.id);
        expect(profile.email, email);
        expect(profile.role, UserRole.player);
      });

      test('lists the active professors, rarest first', () async {
        final list = await professors.getActiveProfessors();
        // The 10 seeded professors are always there. The count is asserted
        // against `collection_progress().total` below instead of a literal,
        // because this local stack is shared and other suites add their own
        // rows; `>= 10` plus "every seeded id is present" is the invariant
        // that actually belongs to the app.
        expect(list.length, greaterThanOrEqualTo(10));
        expect(list.every((p) => p.active), isTrue);
        expect(
          list.map((p) => p.id),
          containsAll(_seedProfessorIds),
          reason: 'the 10 seeded professors must all be listed',
        );
        // Ordering contract: legendary first, then display name.
        final sorted = [...list]..sort(compareProfessors);
        expect(
          list.map((p) => p.id).toList(),
          sorted.map((p) => p.id).toList(),
        );
        expect(
          list.first.rarity.rank,
          greaterThanOrEqualTo(list.last.rarity.rank),
        );

        final henry = list.firstWhere((p) => p.id == _seedProfessorId);
        expect(henry.name, 'Henry Carvajal');
        expect(henry.displayName, 'Prof. Henry');
        expect(henry.rarity, Rarity.common);
        expect(henry.baseCaptureRate, closeTo(0.80, 1e-9));
        expect(henry.spriteUrl, isNull, reason: 'sprite_url is nullable');
        expect(henry.description, isNotNull);
        expect(henry.createdAt, isNotNull);
        // The cache now holds the last known state for the offline UI.
        expect(professors.cache.professors, hasLength(list.length));
        totalProfessors = list.length;
      });

      test('a fresh user starts at 0 captures', () async {
        expect(await professors.getMyCaptures(), isEmpty);
        final progress = await professors.getProgress();
        expect(progress.captured, 0);
        expect(progress.total, totalProfessors);
        expect(progress.completed, isFalse);
      });

      test('MISS always fails and closes the encounter', () async {
        final encounter = await captures.startEncounter(_seedTag);
        expect(encounter.id, isNotEmpty);
        expect(encounter.professor.id, _seedProfessorId);
        expect(encounter.professor.displayName, 'Prof. Henry');
        expect(encounter.professor.rarity, Rarity.common);
        expect(encounter.expiresAt.isUtc, isTrue);
        expect(encounter.expiresAt.isAfter(DateTime.now().toUtc()), isTrue);
        expect(captures.cachedEncounter(encounter.id), isNotNull);

        final result = await captures.resolveCapture(
          encounterId: encounter.id,
          quality: ThrowQuality.miss,
        );
        expect(result.success, isFalse);
        expect(result.retryRequiresNewNfcScan, isTrue);
        expect(result.professorId, isNull);

        // The encounter is over: resolving again is ENCOUNTER_NOT_ACTIVE (409).
        await expectLater(
          captures.resolveCapture(
            encounterId: encounter.id,
            quality: ThrowQuality.good,
          ),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppException.encounterNotActive,
            ),
          ),
        );
      });

      test('EXCELLENT on a COMMON professor always succeeds', () async {
        final encounter = await captures.startEncounter(_seedTag);
        final result = await captures.resolveCapture(
          encounterId: encounter.id,
          quality: ThrowQuality.excellent,
        );
        expect(result.success, isTrue);
        expect(result.professorId, _seedProfessorId);
        expect(result.collection?.captured, 1);
        expect(result.collection?.total, totalProfessors);
        expect(result.collection?.completed, isFalse);
        expect(
          captures.cachedEncounter(encounter.id)?.status,
          EncounterStatus.success,
        );
      });

      test(
        'progress is 1 of the collection and the capture row is the user\'s',
        () async {
          final progress = await professors.getProgress();
          expect(progress.captured, 1);
          expect(progress.total, totalProfessors);
          expect(progress.completed, isFalse);

          final rows = await professors.getMyCaptures();
          expect(rows, hasLength(1));
          expect(rows.single.professorId, _seedProfessorId);
          expect(rows.single.userId, userId);
          expect(rows.single.throwQuality, ThrowQuality.excellent);
          expect(rows.single.capturedAt.isUtc, isTrue);
        },
      );

      test('a second encounter on the same tag is ALREADY_CAPTURED', () async {
        await expectLater(
          captures.startEncounter(_seedTag),
          throwsA(
            isA<AppException>()
                .having((e) => e.code, 'code', AppException.alreadyCaptured)
                .having(
                  (e) => e.message,
                  'message',
                  'Ya capturaste a este profesor',
                ),
          ),
        );
      });

      test('an unknown tag is TAG_NOT_FOUND', () async {
        await expectLater(
          captures.startEncounter('NO-SUCH-TAG-${DateTime.now().microsecond}'),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppException.tagNotFound,
            ),
          ),
        );
      });

      test('an unknown encounter is ENCOUNTER_NOT_FOUND', () async {
        await expectLater(
          captures.resolveCapture(
            encounterId: '00000000-0000-4000-8000-0000000000ff',
            quality: ThrowQuality.good,
          ),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppException.encounterNotFound,
            ),
          ),
        );
      });

      test('an invalid throw quality is INVALID_INPUT', () async {
        // The enum cannot produce a bad value, so go one level lower and hit
        // the function with the same client the service uses.
        await expectLater(
          client.functions.invoke(
            'resolve-capture',
            body: {'encounter_id': 'not-a-uuid', 'throw_quality': 'NOPE'},
          ),
          throwsA(
            isA<FunctionException>().having(
              (e) => AppException.from(e).code,
              'mapped code',
              AppException.invalidInput,
            ),
          ),
        );
      });

      test('signing out makes the session-scoped calls fail', () async {
        await auth.signOut();
        expect(auth.currentUser, isNull);
        await expectLater(
          captures.startEncounter(_seedTag),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppException.unauthorized,
            ),
          ),
        );
        await expectLater(
          professors.getMyCaptures(),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              AppException.unauthorized,
            ),
          ),
        );
      });
    },
    skip: configured
        ? false
        : 'Live backend test: pass --dart-define=SUPABASE_LIVE_URL=... and '
              '--dart-define=SUPABASE_LIVE_ANON_KEY=... to run it.',
  );
}

/// In-memory stand-in for `SharedPreferencesGotrueAsyncStorage`, which the
/// app gets from `Supabase.initialize()` and a bare [SupabaseClient] does not.
class _MemoryPkceStore extends GotrueAsyncStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

/// Deletes the throw-away user through the Auth admin REST endpoint.
Future<void> _deleteUser(String id) async {
  final uri = Uri.parse('$_liveUrl/auth/v1/admin/users/$id');
  final httpClient = HttpClient();
  try {
    final request = await httpClient.deleteUrl(uri);
    request.headers
      ..set('apikey', _liveServiceKey)
      ..set('Authorization', 'Bearer $_liveServiceKey')
      ..set('Content-Type', 'application/json');
    request.add(utf8.encode(jsonEncode({'should_soft_delete': false})));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 300) {
      // ignore: avoid_print
      print('WARN: could not delete $id (${response.statusCode}): $body');
    }
  } finally {
    httpClient.close(force: true);
  }
}
