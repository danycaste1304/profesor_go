import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profesor_go/app/router.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/features/auth/presentation/splash_screen.dart';

import 'auth_test_utils.dart';

void main() {
  const user = AuthUser(id: 'u1', email: 'ana@uni.edu');

  /// Auth repository whose stream never resolves (worst case for the splash).
  FakeAuthRepository hangingAuthRepository({AuthUser? current}) {
    final repo = FakeAuthRepository();
    final controller = StreamController<AuthUser?>();
    addTearDown(controller.close);
    when(() => repo.authState()).thenAnswer((_) => controller.stream);
    when(() => repo.currentUser).thenReturn(current);
    return repo;
  }

  Future<void> pumpSplash(WidgetTester tester, FakeAuthRepository repo) async {
    await tester.pumpWidget(
      buildTestApp(
        screen: const SplashScreen(),
        path: AppRoutes.splash,
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the logo and a loading label while auth resolves', (
    tester,
  ) async {
    await pumpSplash(tester, hangingAuthRepository());

    expect(find.text('Profesor GO'), findsOneWidget);
    expect(find.text('CARGANDO...'), findsOneWidget);
    expect(find.text('MODO DEMO'), findsOneWidget);

    // Still on the splash before the fallback delay.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('falls back to /login after 3s when signed out', (tester) async {
    await pumpSplash(tester, hangingAuthRepository());

    await tester.pump(SplashScreen.fallbackDelay);
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text(routeMarkers[AppRoutes.login]!), findsOneWidget);
  });

  testWidgets('falls back to /map after 3s when a session exists', (
    tester,
  ) async {
    await pumpSplash(tester, hangingAuthRepository(current: user));

    await tester.pump(SplashScreen.fallbackDelay);
    await tester.pumpAndSettle();

    expect(find.text(routeMarkers[AppRoutes.map]!), findsOneWidget);
  });

  testWidgets('does not navigate on its own once auth has resolved', (
    tester,
  ) async {
    // The real router guard handles this case; the splash itself just waits.
    await pumpSplash(tester, stubbedAuthRepository());
    await tester.pump();

    expect(find.text('LISTO'), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(SplashScreen.fallbackDelay);
    await tester.pumpAndSettle();
    expect(find.text(routeMarkers[AppRoutes.login]!), findsOneWidget);
  });
}
