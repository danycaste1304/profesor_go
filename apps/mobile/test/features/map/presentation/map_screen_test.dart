import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:profesor_go/app/router.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/audio/game_music_controller.dart';
import 'package:profesor_go/core/config/campus_config.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/location/lat_lng.dart';
import 'package:profesor_go/core/location/location_service.dart';
import 'package:profesor_go/core/location/mock_location_service.dart';
import 'package:profesor_go/core/mock/demo_game_state.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/repositories/mock_professor_repository.dart';
import 'package:profesor_go/core/repositories/professor_repository.dart';
import 'package:profesor_go/core/widgets/pixel_button.dart';
import 'package:profesor_go/core/widgets/pixel_icon_button.dart';
import 'package:profesor_go/features/map/domain/campus_map_config.dart';
import 'package:profesor_go/features/map/presentation/map_controller.dart';
import 'package:profesor_go/features/map/presentation/map_screen.dart';
import 'package:profesor_go/features/map/presentation/widgets/campus_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = AuthUser(id: 'demo-user', email: 'player@profesorgo.local');

class Harness {
  Harness({
    required this.location,
    required this.repository,
    this.online = true,
    this.musicPlayer,
  });

  final MockLocationService location;
  final ProfessorRepository repository;
  final bool online;
  final GameMusicPlayer? musicPlayer;

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.map,
    routes: [
      GoRoute(
        path: AppRoutes.map,
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (context, state) => const Text('SCAN SCREEN'),
      ),
      GoRoute(
        path: AppRoutes.collection,
        builder: (context, state) => const Text('COLLECTION SCREEN'),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const Text('PROFILE SCREEN'),
      ),
      GoRoute(
        path: AppRoutes.completion,
        builder: (context, state) => const Text('COMPLETION SCREEN'),
      ),
    ],
  );

  Widget build() => ProviderScope(
    overrides: [
      locationServiceProvider.overrideWithValue(location),
      professorRepositoryProvider.overrideWithValue(repository),
      connectivityProvider.overrideWith((ref) => Stream.value(online)),
      authStateProvider.overrideWith((ref) => Stream.value(_user)),
      settingsOpenerProvider.overrideWithValue((status) async {
        settingsRequests.add(status);
        return settingsOpens;
      }),
      if (musicPlayer != null)
        gameMusicPlayerProvider.overrideWithValue(musicPlayer!),
    ],
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );

  /// Statuses the screen asked to open settings for.
  final List<LocationStatus> settingsRequests = [];

  /// What the fake settings opener answers.
  bool settingsOpens = false;
}

class _FakeMusicPlayer implements GameMusicPlayer {
  int plays = 0;
  int pauses = 0;

  @override
  void onComplete(void Function() callback) {}

  @override
  Future<void> play(GameMusicCue cue) async => plays++;

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> dispose() async {}
}

MockLocationService makeLocation({LocationStatus? status}) {
  final service = MockLocationService(
    stepInterval: const Duration(days: 1),
    autoWalk: false,
  );
  if (status != null) service.statusOverride = status;
  return service;
}

MockProfessorRepository makeRepository({int captured = 0}) {
  final state = DemoGameState();
  for (var i = 1; i <= captured; i++) {
    state.addCapture(
      Capture(
        id: 'c$i',
        userId: 'demo-user',
        professorId: demoProfessors[i - 1].id,
        throwQuality: ThrowQuality.good,
        capturedAt: DateTime.utc(2026, 9, 16),
      ),
    );
  }
  return MockProfessorRepository(state, delay: Duration.zero);
}

PixelButton captureButton(WidgetTester tester) =>
    tester.widget<PixelButton>(find.widgetWithText(PixelButton, 'CAPTURAR'));

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> tearDownTree(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(const SizedBox());
  await h.location.dispose();
  h.router.dispose();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders the hub: progress, online chip, map and buttons', (
    tester,
  ) async {
    final h = Harness(
      location: makeLocation(),
      repository: makeRepository(captured: 3),
    );
    await tester.pumpWidget(h.build());
    await settle(tester);

    expect(find.text('CAMPUS USFQ'), findsOneWidget);
    expect(find.text('CAPTURAR'), findsOneWidget);
    expect(captureButton(tester).onPressed, isNotNull);
    expect(find.text('PROFEDEX'), findsOneWidget);
    expect(find.text('PERFIL'), findsOneWidget);
    expect(find.text('Profes Capturados'), findsOneWidget);
    expect(find.text('30 %'), findsOneWidget);
    expect(find.text('EN LÍNEA'), findsOneWidget);
    expect(find.byType(CampusMap), findsOneWidget);
    expect(
      find.widgetWithIcon(PixelIconButton, Icons.directions_walk),
      findsOneWidget,
    );
    expect(find.text('¡Profedex completada!'), findsNothing);
    expect(find.text(MapScreen.offlineCaptureMessage), findsNothing);

    await tester.tap(find.text('CAPTURAR'));
    await tester.pumpAndSettle();
    expect(find.text('SCAN SCREEN'), findsOneWidget);
    await tearDownTree(tester, h);
  });

  testWidgets('music button starts and pauses the original soundtrack', (
    tester,
  ) async {
    final music = _FakeMusicPlayer();
    final h = Harness(
      location: makeLocation(),
      repository: makeRepository(),
      musicPlayer: music,
    );
    await tester.pumpWidget(h.build());
    await settle(tester);

    expect(find.byIcon(Icons.music_off), findsOneWidget);
    await tester.tap(find.widgetWithIcon(PixelIconButton, Icons.music_off));
    await settle(tester);
    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(music.plays, 1);

    await tester.tap(find.widgetWithIcon(PixelIconButton, Icons.music_note));
    await settle(tester);
    expect(find.byIcon(Icons.music_off), findsOneWidget);
    expect(music.pauses, 1);
    await tearDownTree(tester, h);
  });

  testWidgets('offline disables CAPTURAR and explains why', (tester) async {
    final h = Harness(
      location: makeLocation(),
      repository: makeRepository(),
      online: false,
    );
    await tester.pumpWidget(h.build());
    await settle(tester);

    expect(find.text('SIN CONEXIÓN'), findsOneWidget);
    expect(captureButton(tester).onPressed, isNull);
    expect(find.text(MapScreen.offlineCaptureMessage), findsOneWidget);

    await tester.tap(find.text('CAPTURAR'));
    await tester.pumpAndSettle();
    expect(find.text('SCAN SCREEN'), findsNothing);
    expect(find.text('CAPTURAR'), findsOneWidget);
    await tearDownTree(tester, h);
  });

  testWidgets('avatar follows the mock location', (tester) async {
    final h = Harness(location: makeLocation(), repository: makeRepository());
    await tester.pumpWidget(h.build());
    await settle(tester);

    Positioned avatar() => tester.widget<Positioned>(
      find.descendant(
        of: find.byKey(CampusMap.avatarKey),
        matching: find.byType(Positioned),
      ),
    );
    final map = tester.widget<CampusMap>(find.byType(CampusMap));
    final size = map.avatarSize;

    final first = CampusConfig.toMapOffset(CampusConfig.demoPath.first);
    expect(avatar().left, closeTo(first.dx - size / 2, 1e-6));
    expect(avatar().top, closeTo(first.dy - size * 0.92, 1e-6));
    expect(find.text('Estás fuera del campus'), findsNothing);

    const next = LatLng(40.4525, -3.7262);
    h.location.teleport(next);
    await settle(tester);
    final expected = CampusConfig.toMapOffset(next);
    expect(avatar().left, closeTo(expected.dx - size / 2, 1e-6));
    expect(avatar().top, closeTo(expected.dy - size * 0.92, 1e-6));

    h.location.teleport(const LatLng(0, 0));
    await settle(tester);
    expect(find.text('Estás fuera del campus'), findsOneWidget);
    await tearDownTree(tester, h);
  });

  testWidgets('denied location shows the notice with "Abrir ajustes"', (
    tester,
  ) async {
    final h = Harness(
      location: makeLocation(status: LocationStatus.deniedForever),
      repository: makeRepository(),
    );
    await tester.pumpWidget(h.build());
    await settle(tester);

    expect(find.byKey(CampusMap.avatarKey), findsNothing);
    expect(find.textContaining('bloqueado'), findsOneWidget);
    expect(find.text('ABRIR AJUSTES'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);

    // When the settings cannot be opened, a friendly snackbar explains it.
    await tester.tap(find.text('ABRIR AJUSTES'));
    await settle(tester);
    expect(h.settingsRequests, [LocationStatus.deniedForever]);
    expect(find.textContaining('No se pudieron abrir'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // snackbar gone

    // Permission granted meanwhile: retry restores the avatar.
    h.location.statusOverride = LocationStatus.available;
    await tester.tap(find.text('REINTENTAR'));
    await settle(tester);
    expect(find.textContaining('bloqueado'), findsNothing);
    expect(find.byKey(CampusMap.avatarKey), findsOneWidget);
    await tester.pumpAndSettle();
    await tearDownTree(tester, h);
  });

  testWidgets('demo toggle starts the mock walk', (tester) async {
    final h = Harness(location: makeLocation(), repository: makeRepository());
    await tester.pumpWidget(h.build());
    await settle(tester);

    final toggle = find.widgetWithIcon(PixelIconButton, Icons.directions_walk);
    expect(h.location.isWalking, isFalse);
    await tester.tap(toggle);
    await settle(tester);
    expect(h.location.isWalking, isTrue);
    expect(tester.widget<PixelIconButton>(toggle).toggled, isTrue);

    await tester.tap(toggle);
    await settle(tester);
    expect(h.location.isWalking, isFalse);
    await tester.pumpAndSettle();
    await tearDownTree(tester, h);
  });

  testWidgets('completed collection shows the banner once', (tester) async {
    final h = Harness(
      location: makeLocation(),
      repository: makeRepository(captured: 10),
    );
    await tester.pumpWidget(h.build());
    await settle(tester);

    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('¡Profedex completada!'), findsOneWidget);

    await tester.tap(find.text('VER'));
    await tester.pumpAndSettle();
    expect(find.text('COMPLETION SCREEN'), findsOneWidget);

    h.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('CAPTURAR'), findsOneWidget);
    expect(find.text('¡Profedex completada!'), findsNothing);
    await tearDownTree(tester, h);
  });

  testWidgets('secondary buttons navigate to collection and profile', (
    tester,
  ) async {
    final h = Harness(location: makeLocation(), repository: makeRepository());
    await tester.pumpWidget(h.build());
    await settle(tester);

    await tester.tap(find.text('PROFEDEX'));
    await tester.pumpAndSettle();
    expect(find.text('COLLECTION SCREEN'), findsOneWidget);
    h.router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('PERFIL'));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE SCREEN'), findsOneWidget);
    await tearDownTree(tester, h);
  });

  testWidgets('uses a custom map config from the provider', (tester) async {
    final h = Harness(location: makeLocation(), repository: makeRepository());
    const config = CampusMapConfig(mapWidth: 300, mapHeight: 300);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(h.location),
          professorRepositoryProvider.overrideWithValue(h.repository),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          authStateProvider.overrideWith((ref) => Stream.value(_user)),
          campusMapConfigProvider.overrideWithValue(config),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: h.router,
        ),
      ),
    );
    await settle(tester);
    final map = tester.widget<CampusMap>(find.byType(CampusMap));
    expect(map.config.mapWidth, 300);
    await tearDownTree(tester, h);
  });
}
