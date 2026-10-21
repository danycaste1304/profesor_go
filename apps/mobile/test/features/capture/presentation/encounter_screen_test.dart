import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/featured_professors.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/repositories/capture_service.dart';
import 'package:profesor_go/core/widgets/widgets.dart';
import 'package:profesor_go/features/capture/domain/capture_result_args.dart';
import 'package:profesor_go/features/capture/presentation/encounter_screen.dart';

import '../fakes.dart';

void main() {
  late FakeCaptureService service;

  setUp(() => service = FakeCaptureService());

  GoRouter router({String encounterId = 'enc-1', Object? extra}) {
    final r = GoRouter(
      initialLocation: '/encounter/$encounterId',
      initialExtra: extra,
      routes: [
        GoRoute(
          path: '/encounter/:encounterId',
          builder: (_, s) =>
              EncounterScreen(encounterId: s.pathParameters['encounterId']!),
        ),
        GoRoute(
          path: '/result',
          builder: (_, s) {
            final args = s.extra as CaptureResultArgs?;
            return StubPage(
              'RESULT ${args?.success} ${args?.quality?.wireValue}',
            );
          },
        ),
        GoRoute(path: '/map', builder: (_, _) => const StubPage('MAP')),
        GoRoute(path: '/scan', builder: (_, _) => const StubPage('SCAN')),
      ],
    );
    addTearDown(r.dispose);
    return r;
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    Encounter? extra,
    String id = 'enc-1',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          captureServiceProvider.overrideWithValue(service as CaptureService),
        ],
        child: testApp(
          router: router(encounterId: id, extra: extra),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> dragOntoSprite(WidgetTester tester) async {
    final ball = tester.getCenter(find.byType(CaptureBall));
    final sprite = tester.getCenter(find.byType(ProfessorSprite));
    await tester.drag(find.byType(CaptureBall), sprite - ball);
    await tester.pump();
  }

  testWidgets('renders professor name, rarity, countdown and instructions', (
    tester,
  ) async {
    await pumpScreen(tester, extra: makeEncounter());
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Prof. Ricardo'), findsOneWidget);
    expect(find.text('RARA'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^0[23]:[0-5]\d$')), findsOneWidget);
    expect(find.text('Desliza hacia arriba y suelta'), findsOneWidget);
    expect(find.byType(CaptureBall), findsOneWidget);
    expect(find.byType(ProfessorSprite), findsOneWidget);
    // Idle animations keep running without errors.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Daniel introduces himself before the throw instruction', (
    tester,
  ) async {
    final encounter = makeEncounter().copyWith(
      professor: demoProfessors[6].summary,
    );
    await pumpScreen(tester, extra: encounter);
    expect(find.text('Prof. Daniel'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RetroDialogue &&
            widget.text.contains(danielRiofrioCatchphrase),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<ProfessorSprite>(find.byType(ProfessorSprite)).pose,
      ProfessorSpritePose.fullBody,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Desliza hacia arriba y suelta'), findsOneWidget);
  });

  testWidgets('Erick has a playful introduction before the throw', (
    tester,
  ) async {
    final encounter = makeEncounter().copyWith(
      professor: demoProfessors[7].summary,
    );
    await pumpScreen(tester, extra: encounter);
    expect(find.text('Prof. Erick'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RetroDialogue && widget.text == erickNaunayIntro,
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<ProfessorSprite>(find.byType(ProfessorSprite)).pose,
      ProfessorSpritePose.fullBody,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Desliza hacia arriba y suelta'), findsOneWidget);
  });

  testWidgets('Noel introduces the social learning theme', (tester) async {
    final encounter = makeEncounter().copyWith(
      professor: demoProfessors[5].summary,
    );
    await pumpScreen(tester, extra: encounter);
    expect(find.text('Prof. Noel'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RetroDialogue && widget.text == noelPerezIntro,
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<ProfessorSprite>(find.byType(ProfessorSprite)).pose,
      ProfessorSpritePose.fullBody,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Desliza hacia arriba y suelta'), findsOneWidget);
  });

  testWidgets('Pavel welcomes the player to the AI laboratory', (tester) async {
    final encounter = makeEncounter().copyWith(
      professor: demoProfessors[4].summary,
    );
    await pumpScreen(tester, extra: encounter);
    expect(find.text('Prof. Pavel'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RetroDialogue && widget.text == pavelAlbaIntro,
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<ProfessorSprite>(find.byType(ProfessorSprite)).pose,
      ProfessorSpritePose.fullBody,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Desliza hacia arriba y suelta'), findsOneWidget);
  });

  testWidgets('Ricardo introduces the networks encounter', (tester) async {
    final encounter = makeEncounter().copyWith(
      professor: demoProfessors[3].summary,
    );
    await pumpScreen(tester, extra: encounter);
    expect(find.text('Prof. Ricardo'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RetroDialogue && widget.text == ricardoFloresIntro,
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<ProfessorSprite>(find.byType(ProfessorSprite)).pose,
      ProfessorSpritePose.fullBody,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Desliza hacia arriba y suelta'), findsOneWidget);
  });

  testWidgets('Jose David has a welcoming introduction and full sprite', (
    tester,
  ) async {
    final encounter = makeEncounter().copyWith(
      professor: demoProfessors[2].summary,
    );
    await pumpScreen(tester, extra: encounter);
    expect(find.text('Prof. Jose David'), findsOneWidget);
    expect(find.text('COMÚN'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RetroDialogue && widget.text == joseDavidVegaIntro,
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<ProfessorSprite>(find.byType(ProfessorSprite)).pose,
      ProfessorSpritePose.fullBody,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Desliza hacia arriba y suelta'), findsOneWidget);
  });

  testWidgets('Felipe has a thoughtful introduction and full sprite', (
    tester,
  ) async {
    final encounter = makeEncounter().copyWith(
      professor: demoProfessors[1].summary,
    );
    await pumpScreen(tester, extra: encounter);
    expect(find.text('Prof. Felipe'), findsOneWidget);
    expect(find.text('ÉPICA'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RetroDialogue && widget.text == felipeGrijalvaIntro,
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<ProfessorSprite>(find.byType(ProfessorSprite)).pose,
      ProfessorSpritePose.fullBody,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Desliza hacia arriba y suelta'), findsOneWidget);
  });

  testWidgets('recovers the encounter from the service cache without extra', (
    tester,
  ) async {
    service.remember(makeEncounter(id: 'cached-1'));
    await pumpScreen(tester, id: 'cached-1');
    expect(find.text('Prof. Ricardo'), findsOneWidget);
  });

  testWidgets('missing encounter shows an error with a way back', (
    tester,
  ) async {
    await pumpScreen(tester, id: 'ghost');
    expect(
      find.text(AppException.messages[AppException.encounterNotFound]!),
      findsOneWidget,
    );
    await tester.tap(find.text('VOLVER AL MAPA'));
    await tester.pumpAndSettle();
    expect(find.text('MAP'), findsOneWidget);
  });

  testWidgets('drag onto the sprite resolves the capture and shows success', (
    tester,
  ) async {
    service.result = const CaptureResult(
      success: true,
      professorId: 'p4',
      collection: CollectionProgress(captured: 1, total: 8, completed: false),
    );
    await pumpScreen(tester, extra: makeEncounter());

    await dragOntoSprite(tester);

    // Backend called right on release (in parallel with the animation).
    expect(service.resolved, hasLength(1));
    expect(service.resolved.single.encounterId, 'enc-1');
    expect(service.resolved.single.quality, isNot(ThrowQuality.miss));
    expect(find.text('¡Excelente!'), findsOneWidget);

    var sawCaptured = false;
    final navigated = await pumpUntilFound(
      tester,
      find.textContaining('RESULT true'),
      onStep: () =>
          sawCaptured |= find.text('¡Capturado!').evaluate().isNotEmpty,
    );
    expect(sawCaptured, isTrue, reason: 'burst state should show ¡Capturado!');
    expect(navigated, isTrue);
    expect(find.text('RESULT true EXCELLENT'), findsOneWidget);
  });

  testWidgets('a short flick from the launch area visibly flies and captures', (
    tester,
  ) async {
    service.result = const CaptureResult(
      success: true,
      professorId: 'p4',
      collection: CollectionProgress(captured: 1, total: 8, completed: false),
    );
    await pumpScreen(tester, extra: makeEncounter());
    final rest = tester.getCenter(find.byType(CaptureBall));
    final target = tester.getCenter(find.byType(ProfessorSprite));

    // Start just below the painted ball: the generous launch pad accepts it.
    await tester.dragFrom(rest + const Offset(0, 58), const Offset(0, -125));
    await tester.pump();
    expect(service.resolved.single.quality, ThrowQuality.excellent);

    await tester.pump(const Duration(milliseconds: 100));
    final inFlight = tester.getCenter(find.byType(CaptureBall));
    expect(inFlight.dy, lessThan(rest.dy - 70));
    expect(inFlight.dy, greaterThan(target.dy + 25));

    final navigated = await pumpUntilFound(
      tester,
      find.textContaining('RESULT true'),
    );
    expect(navigated, isTrue);
  });

  testWidgets('aim guide appears during an upward drag and clears on release', (
    tester,
  ) async {
    await pumpScreen(tester, extra: makeEncounter());
    final ball = tester.getCenter(find.byType(CaptureBall));
    final gesture = await tester.startGesture(ball);
    await gesture.moveBy(const Offset(0, -28));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.text('DESLIZA MÁS'), findsOneWidget);
    await gesture.moveBy(const Offset(0, -52));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.byKey(const Key('encounter-aim-guide')), findsOneWidget);
    expect(find.text('¡EXCELENTE!'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(find.byKey(const Key('encounter-aim-guide')), findsNothing);
    expect(service.resolved, hasLength(1));
  });

  testWidgets('a short drag is a MISS and shows the escape state', (
    tester,
  ) async {
    await pumpScreen(tester, extra: makeEncounter());

    await tester.drag(find.byType(CaptureBall), const Offset(0, -30));
    await tester.pump();

    expect(service.resolved.single.quality, ThrowQuality.miss);
    expect(find.text('¡Fallaste!'), findsOneWidget);

    var sawEscape = false;
    final navigated = await pumpUntilFound(
      tester,
      find.textContaining('RESULT false'),
      onStep: () => sawEscape |= find.text('¡Se escapó!').evaluate().isNotEmpty,
    );
    expect(sawEscape, isTrue);
    expect(navigated, isTrue);
    expect(find.text('RESULT false MISS'), findsOneWidget);
  });

  testWidgets('a good throw the backend rejects shows the escape state', (
    tester,
  ) async {
    service.result = const CaptureResult.failed();
    await pumpScreen(tester, extra: makeEncounter());
    await dragOntoSprite(tester);
    var sawEscape = false;
    await pumpUntilFound(
      tester,
      find.textContaining('RESULT false'),
      onStep: () => sawEscape |= find.text('¡Se escapó!').evaluate().isNotEmpty,
    );
    expect(sawEscape, isTrue);
    expect(find.textContaining('RESULT false'), findsOneWidget);
  });

  testWidgets('a tap on the ball is not a throw', (tester) async {
    await pumpScreen(tester, extra: makeEncounter());
    await tester.tap(find.byType(CaptureBall));
    await tester.pump();
    expect(service.resolved, isEmpty);
    expect(find.byType(CaptureBall), findsOneWidget);
  });

  testWidgets('only one throw is submitted even with repeated gestures', (
    tester,
  ) async {
    service.resolveGate = Completer<void>();
    await pumpScreen(tester, extra: makeEncounter());
    await dragOntoSprite(tester);
    await tester.pump(const Duration(milliseconds: 100));
    // Second gesture while the first is in flight.
    await tester.drag(find.byType(CaptureBall), const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.resolved, hasLength(1));
    service.resolveGate!.complete();
    await pumpUntilFound(tester, find.textContaining('RESULT'));
    expect(service.resolved, hasLength(1));
  });

  testWidgets(
    'expired encounter shows the expiry dialog and goes back to the map',
    (tester) async {
      await pumpScreen(
        tester,
        extra: makeEncounter(ttl: const Duration(seconds: -1)),
      );
      await tester.pump();
      expect(find.text('El encuentro expiró'), findsOneWidget);
      expect(
        find.text(AppException.messages[AppException.encounterExpired]!),
        findsOneWidget,
      );
      expect(find.text('00:00'), findsOneWidget);

      await tester.tap(find.text('VOLVER AL MAPA'));
      await tester.pumpAndSettle();
      expect(find.text('MAP'), findsOneWidget);
    },
  );

  testWidgets(
    'backend error during the throw shows a dialog and goes back to the map',
    (tester) async {
      service.resolveError = AppException.fromCode(
        AppException.encounterNotActive,
      );
      await pumpScreen(tester, extra: makeEncounter());
      await dragOntoSprite(tester);
      final shown = await pumpUntilFound(
        tester,
        find.text('El encuentro terminó'),
      );
      expect(shown, isTrue);
      expect(
        find.text(AppException.messages[AppException.encounterNotActive]!),
        findsOneWidget,
      );

      await tester.tap(find.text('VOLVER AL MAPA'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('MAP'), findsOneWidget);
      expect(find.textContaining('RESULT'), findsNothing);
    },
  );

  testWidgets('offline error shows the no-internet dialog', (tester) async {
    service.resolveError = AppException.fromCode(AppException.noInternet);
    await pumpScreen(tester, extra: makeEncounter());
    await dragOntoSprite(tester);
    final shown = await pumpUntilFound(tester, find.text('Sin conexión'));
    expect(shown, isTrue);
    expect(
      find.text(AppException.messages[AppException.noInternet]!),
      findsOneWidget,
    );
  });

  testWidgets('already resolved encounter shows the not-active message', (
    tester,
  ) async {
    service.remember(
      makeEncounter(id: 'done-1', status: EncounterStatus.failed),
    );
    await pumpScreen(tester, id: 'done-1');
    expect(
      find.text(AppException.messages[AppException.encounterNotActive]!),
      findsOneWidget,
    );
  });
}
