import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/mock/demo_game_state.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/repositories/mock_auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late MockAuthRepository repo;

  setUp(() => repo = MockAuthRepository(delay: Duration.zero));
  tearDown(() => repo.dispose());

  test('starts signed out and emits on sign in / out', () async {
    final events = <AuthUser?>[];
    final sub = repo.authState().listen(events.add);
    await Future<void>.delayed(Duration.zero);
    expect(events, [null]);
    expect(repo.currentUser, isNull);

    await repo.signIn('Player@Uni.edu', 'secret');
    expect(repo.currentUser?.email, 'player@uni.edu');
    await repo.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 3);
    expect(events[1]?.email, 'player@uni.edu');
    expect(events[2], isNull);
    await sub.cancel();
  });

  test('signUp stores the display name and getProfile returns it', () async {
    await repo.signUp('ana@uni.edu', '12345678', displayName: 'Ana');
    expect(repo.currentUser?.displayName, 'Ana');
    final profile = await repo.getProfile();
    expect(profile?.displayName, 'Ana');
    expect(profile?.role, UserRole.player);
    await repo.signOut();
    expect(await repo.getProfile(), isNull);
    await repo.signIn('ana@uni.edu', 'whatever');
    expect(repo.currentUser?.displayName, 'Ana');
  });

  test('validates obviously bad input', () async {
    await expectLater(
      repo.signIn('', ''),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppException.invalidCredentials,
        ),
      ),
    );
    await expectLater(
      repo.signUp('x@y.z', '123'),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppException.weakPassword,
        ),
      ),
    );
  });

  test(
    'restores the completion date before returning the demo profile',
    () async {
      SharedPreferences.setMockInitialValues({});
      final completedAt = DateTime.utc(2026, 10, 16, 12, 30);
      final original = DemoGameState(
        persist: true,
        professors: [demoProfessors.first],
        clock: () => completedAt,
      );
      await original.ensureLoaded();
      await original.addCapture(
        Capture(
          id: 'capture-1',
          userId: 'demo-user',
          professorId: demoProfessors.first.id,
          encounterId: 'encounter-1',
          throwQuality: ThrowQuality.great,
          capturedAt: completedAt,
        ),
      );

      final restored = DemoGameState(
        persist: true,
        professors: [demoProfessors.first],
      );
      final auth = MockAuthRepository(
        delay: Duration.zero,
        gameState: restored,
      );
      addTearDown(auth.dispose);
      await auth.signIn('player@uni.edu', 'secret');

      expect((await auth.getProfile())?.collectionCompletedAt, completedAt);
    },
  );
}
