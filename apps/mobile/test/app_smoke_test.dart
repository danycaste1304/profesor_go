import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/app/app.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/location/mock_location_service.dart';
import 'package:profesor_go/core/mock/demo_game_state.dart';
import 'package:profesor_go/core/repositories/mock_auth_repository.dart';
import 'package:profesor_go/core/repositories/mock_capture_service.dart';
import 'package:profesor_go/core/repositories/mock_professor_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('demo app boots to /login and reaches /map after sign in',
      (tester) async {
    final state = DemoGameState();
    final auth = MockAuthRepository(delay: Duration.zero, gameState: state);
    final location = MockLocationService(
      stepInterval: const Duration(days: 1),
      autoWalk: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoGameStateProvider.overrideWithValue(state),
          authRepositoryProvider.overrideWithValue(auth),
          // Zero latency so no simulated-network timer outlives the test.
          professorRepositoryProvider.overrideWithValue(
            MockProfessorRepository(state, delay: Duration.zero),
          ),
          captureServiceProvider.overrideWithValue(
            MockCaptureService(state, delay: Duration.zero),
          ),
          locationServiceProvider.overrideWithValue(location),
        ],
        child: const App(),
      ),
    );
    // Splash while the auth stream resolves, then the redirect to /login.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);

    await auth.signIn('player@profesorgo.local', 'player12345');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Campus USFQ'), findsOneWidget);
    expect(find.text('CAPTURAR'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);

    // Unmount before disposing the services the screens are still using.
    await tester.pumpWidget(const SizedBox());
    await location.dispose();
    await auth.dispose();
  });
}
