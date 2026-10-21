import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profesor_go/app/router.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/repositories/auth_repository.dart';
import 'package:profesor_go/core/repositories/professor_repository.dart';

class FakeAuthRepository extends Mock implements AuthRepository {}

class FakeProfessorRepository extends Mock implements ProfessorRepository {}

/// A fully stubbed [FakeAuthRepository]: every call succeeds, the auth stream
/// emits [user] once (null = signed out) and `getProfile` returns [profile].
FakeAuthRepository stubbedAuthRepository({AuthUser? user, Profile? profile}) {
  final repo = FakeAuthRepository();
  when(() => repo.authState()).thenAnswer((_) => Stream.value(user));
  when(() => repo.currentUser).thenReturn(user);
  when(() => repo.getProfile()).thenAnswer((_) async => profile);
  when(() => repo.signIn(any(), any())).thenAnswer((_) async {});
  when(() => repo.signUp(any(), any(), displayName: any(named: 'displayName')))
      .thenAnswer((_) async {});
  when(() => repo.signOut()).thenAnswer((_) async {});
  return repo;
}

/// Marker text rendered by every app route other than the screen under test,
/// so tests can assert `context.go(...)` calls without the real screens.
const Map<String, String> routeMarkers = {
  AppRoutes.splash: 'SPLASH_ROUTE',
  AppRoutes.login: 'LOGIN_ROUTE',
  AppRoutes.register: 'REGISTER_ROUTE',
  AppRoutes.map: 'MAP_ROUTE',
  AppRoutes.collection: 'COLLECTION_ROUTE',
};

/// Builds a [ProviderScope] + [MaterialApp.router] with [screen] mounted at
/// [path] and marker pages for the other routes (no auth redirect).
Widget buildTestApp({
  required Widget screen,
  required List<Override> overrides,
  String path = '/',
}) {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(path: path, builder: (_, _) => screen),
      for (final entry in routeMarkers.entries)
        if (entry.key != path)
          GoRoute(
            path: entry.key,
            builder: (_, _) => Scaffold(body: Center(child: Text(entry.value))),
          ),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}

/// Scrolls [finder] into view, lets the frame settle, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}
