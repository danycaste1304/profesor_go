// End-to-end demo flow as a widget test (no `integration_test` package):
// the real `App` + router + screens, with the demo (mock) services injected
// so the outcome is deterministic.
//
//   login → map (CAPTURAR) → /scan (choose DEMO-TAG-01) → /encounter/:id
//   → drag the ball onto the professor → /result "¡CAPTURADO!" → /collection
//   shows 1 / 10 with Prof. Henry revealed.
//
// The throw is a real drag gesture (the encounter screen evaluates the
// release point against the sprite); the animations run on fake time.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/app/app.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/location/mock_location_service.dart';
import 'package:profesor_go/core/mock/demo_game_state.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/featured_professors.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/nfc/mock_nfc_service.dart';
import 'package:profesor_go/core/repositories/mock_auth_repository.dart';
import 'package:profesor_go/core/repositories/mock_capture_service.dart';
import 'package:profesor_go/core/repositories/mock_professor_repository.dart';
import 'package:profesor_go/core/widgets/widgets.dart';
import 'package:profesor_go/features/auth/presentation/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deterministic [Random]: every roll is 0, so `roll < p` always succeeds
/// (for any quality except MISS, whose probability is 0).
class AlwaysSucceedRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

/// Pumps in [step]s until [finder] matches or [timeout] elapses (fake time).
Future<bool> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 50),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < timeout) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.pump(step);
    elapsed += step;
  }
  return finder.evaluate().isNotEmpty;
}

/// A few short pumps: lets futures, the router refresh and the zero-length
/// timers of the loading views settle.
Future<void> settle(WidgetTester tester, [int times = 3]) async {
  await tester.pump();
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'demo flow: login → map → scan → encounter → throw → result → collection',
    (tester) async {
      // Phone-like portrait surface, tall enough for the whole collection
      // grid to be laid out (slivers build lazily).
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = DemoGameState();
      final auth = MockAuthRepository(delay: Duration.zero, gameState: state);
      final nfc = MockNfcService(delay: const Duration(milliseconds: 300))
        ..selectTag('DEMO-TAG-01');
      final location = MockLocationService(
        stepInterval: const Duration(days: 1),
        autoWalk: false,
      );
      final capture = MockCaptureService(
        state,
        random: AlwaysSucceedRandom(),
        delay: Duration.zero,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            demoGameStateProvider.overrideWithValue(state),
            authRepositoryProvider.overrideWithValue(auth),
            nfcServiceProvider.overrideWithValue(nfc),
            locationServiceProvider.overrideWithValue(location),
            professorRepositoryProvider.overrideWithValue(
              MockProfessorRepository(state, delay: Duration.zero),
            ),
            captureServiceProvider.overrideWithValue(capture),
          ],
          child: const App(),
        ),
      );

      // 1. Splash → /login (auth stream resolves with "signed out").
      await settle(tester);
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);

      // 2. Sign in with the demo player → router guard sends us to /map.
      await tester.enterText(
        find.byKey(LoginScreen.emailKey),
        LoginScreen.demoEmail,
      );
      await tester.enterText(
        find.byKey(LoginScreen.passwordKey),
        LoginScreen.demoPassword,
      );
      await tester.tap(find.byKey(LoginScreen.submitKey));
      await settle(tester);
      expect(find.text('CAMPUS USFQ'), findsOneWidget);
      expect(find.text('0 %'), findsOneWidget);
      final captureButton = find.widgetWithText(PixelButton, 'CAPTURAR');
      expect(captureButton, findsOneWidget);
      expect(tester.widget<PixelButton>(captureButton).onPressed, isNotNull);

      // 3. CAPTURAR → /scan. Choosing the demo card starts an encounter.
      await tester.tap(captureButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('LEER TARJETA'), findsOneWidget);
      expect(find.text('TARJETAS DEMO'), findsOneWidget);
      expect(find.text('Elige una tarjeta demo'), findsOneWidget);
      await tester.ensureVisible(find.text('Prof. Henry'));
      await tester.tap(find.text('Prof. Henry'));
      final onEncounter = await pumpUntilFound(tester, find.text('ENCUENTRO'));
      expect(onEncounter, isTrue, reason: 'scan should open the encounter');
      final encounter = capture.lastEncounter;
      expect(encounter, isNotNull);
      expect(encounter!.professor.id, demoProfessors.first.id);
      expect(find.text('Prof. Henry'), findsOneWidget);
      expect(find.text('COMÚN'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^0[23]:[0-5]\d$')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(henryCarvajalIntro), findsOneWidget);

      // 4. A good throw: drag the ball onto the professor sprite. The
      //    release point is on the target, so the quality is EXCELLENT and
      //    the seeded roll (0) makes the capture succeed.
      final ball = tester.getCenter(find.byType(CaptureBall));
      final sprite = tester.getCenter(find.byType(ProfessorSprite));
      await tester.drag(find.byType(CaptureBall), sprite - ball);
      await tester.pump();
      expect(find.text('¡Excelente!'), findsOneWidget);
      expect(
        state.encounterById(encounter.id)?.status,
        EncounterStatus.success,
      );

      // 5. Fly / absorb / drop / shake / burst animations, then /result.
      final onResult = await pumpUntilFound(tester, find.text('¡CAPTURADO!'));
      expect(onResult, isTrue, reason: 'throw should end on the result screen');
      expect(find.text('¡CAPTURADO!'), findsOneWidget); // app bar title
      expect(find.text('Lanzamiento: Excelente'), findsOneWidget);
      expect(find.text('10 %'), findsOneWidget);
      expect(state.isCaptured(demoProfessors.first.id), isTrue);

      // 6. "Ver Profedex" → /collection shows the capture.
      await tester.tap(find.widgetWithText(PixelButton, 'VER PROFEDEX'));
      await settle(tester);
      expect(find.text('MI PROFEDEX'), findsOneWidget);
      expect(find.text('10 %'), findsOneWidget);
      expect(find.byType(ProfessorSprite), findsNWidgets(10));
      expect(find.text('Prof. Henry'), findsOneWidget);
      expect(find.text('???'), findsWidgets);
      final silhouettes = tester
          .widgetList<ProfessorSprite>(find.byType(ProfessorSprite))
          .where((s) => s.silhouette)
          .length;
      expect(silhouettes, 9);

      await tester.tap(find.widgetWithText(PixelButton, 'VOLVER AL MAPA'));
      await settle(tester);
      expect(find.widgetWithText(PixelButton, 'CAPTURAR'), findsOneWidget);

      // Unmount before disposing the services the screens still hold.
      await tester.pumpWidget(const SizedBox());
      await nfc.cancel();
      await location.dispose();
      await auth.dispose();
    },
  );

  test('demo services chain: tag → encounter → GOOD throw → 1 / 8', () async {
    // Same path without widgets: what the screens call, in order.
    final now = DateTime.utc(2026, 9, 16, 10);
    final state = DemoGameState(clock: () => now);
    final nfc = MockNfcService(delay: Duration.zero)..selectTag('DEMO-TAG-01');
    final capture = MockCaptureService(
      state,
      random: AlwaysSucceedRandom(),
      delay: Duration.zero,
    );
    final repository = MockProfessorRepository(state, delay: Duration.zero);

    final tag = await nfc.scanTag();
    expect(tag, 'DEMO-TAG-01');

    final encounter = await capture.startEncounter(tag!);
    expect(encounter.professor.displayName, 'Prof. Henry');
    expect(encounter.expiresAt, now.add(const Duration(seconds: 180)));
    expect(capture.cachedEncounter(encounter.id), encounter);

    final result = await capture.resolveCapture(
      encounterId: encounter.id,
      quality: ThrowQuality.good,
    );
    expect(result.success, isTrue);
    expect(result.professorId, demoProfessors.first.id);
    expect(
      result.collection,
      const CollectionProgress(captured: 1, total: 10, completed: false),
    );

    final progress = await repository.getProgress();
    expect(progress.captured, 1);
    expect(progress.total, 10);
    final captures = await repository.getMyCaptures();
    expect(captures.single.throwQuality, ThrowQuality.good);

    // A second scan of the same card is rejected (ALREADY_CAPTURED).
    await expectLater(
      capture.startEncounter('DEMO-TAG-01'),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppException.alreadyCaptured,
        ),
      ),
    );
  });
}
