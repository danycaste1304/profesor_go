import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/mock/demo_game_state.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/widgets/widgets.dart';
import 'package:profesor_go/features/capture/domain/capture_result_args.dart';
import 'package:profesor_go/features/capture/presentation/capture_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final professor = demoProfessors[7].summary; // Prof. Erick, LEGENDARY

  GoRouter router(CaptureResultArgs args) {
    final r = GoRouter(
      initialLocation: '/result',
      routes: [
        GoRoute(
          path: '/result',
          builder: (_, _) => CaptureResultScreen(args: args),
        ),
        GoRoute(path: '/map', builder: (_, _) => const StubPage('MAP')),
        GoRoute(path: '/scan', builder: (_, _) => const StubPage('SCAN')),
        GoRoute(
          path: '/collection',
          builder: (_, _) => const StubPage('COLLECTION'),
        ),
        GoRoute(
          path: '/completion',
          builder: (_, _) => const StubPage('COMPLETION'),
        ),
      ],
    );
    addTearDown(r.dispose);
    return r;
  }

  Future<void> pumpScreen(WidgetTester tester, CaptureResultArgs args) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoGameStateProvider.overrideWithValue(DemoGameState())],
        child: testApp(router: router(args)),
      ),
    );
    await tester.pump();
  }

  testWidgets('success shows the name, rarity, progress and both buttons', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      CaptureResultArgs(
        professor: professor,
        success: true,
        quality: ThrowQuality.great,
        collection: const CollectionProgress(
          captured: 3,
          total: 8,
          completed: false,
        ),
      ),
    );
    expect(find.text('¡Capturaste a Prof. Erick!'), findsOneWidget);
    expect(find.text('LEGENDARIA'), findsOneWidget);
    expect(find.byType(ProfessorSprite), findsOneWidget);
    expect(find.byType(ProgressBar), findsOneWidget);
    expect(find.text('3 / 8'), findsOneWidget);
    expect(find.text('Lanzamiento: Genial'), findsOneWidget);
    expect(find.text('VER COLECCIÓN'), findsOneWidget);
    expect(find.text('VOLVER AL MAPA'), findsOneWidget);
    expect(find.text('¡COLECCIÓN COMPLETADA!'), findsNothing);

    await tester.tap(find.text('VER COLECCIÓN'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('COLLECTION'), findsOneWidget);
  });

  testWidgets('completed collection offers the completion screen', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      CaptureResultArgs(
        professor: professor,
        success: true,
        collection: const CollectionProgress(
          captured: 8,
          total: 8,
          completed: true,
        ),
      ),
    );
    expect(find.text('¡COLECCIÓN COMPLETADA!'), findsOneWidget);
    await tester.tap(find.text('¡COLECCIÓN COMPLETADA!'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('COMPLETION'), findsOneWidget);
  });

  testWidgets('failure shows the escape copy and goes back to the map', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      CaptureResultArgs(
        professor: professor,
        success: false,
        quality: ThrowQuality.miss,
      ),
    );
    expect(find.text('¡Prof. Erick se escapó!'), findsOneWidget);
    expect(
      find.text(
        'Para intentarlo de nuevo, encuentra al profesor y lee su tarjeta NFC otra vez.',
      ),
      findsOneWidget,
    );
    expect(find.text('Lanzamiento: Fallo'), findsOneWidget);
    expect(find.byType(ProgressBar), findsNothing);
    expect(find.text('VER COLECCIÓN'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester
          .widgetList<ProfessorSprite>(find.byType(ProfessorSprite))
          .where((sprite) => sprite.silhouette),
      hasLength(1),
    );

    await tester.tap(find.text('VOLVER AL MAPA'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('MAP'), findsOneWidget);
  });
}
