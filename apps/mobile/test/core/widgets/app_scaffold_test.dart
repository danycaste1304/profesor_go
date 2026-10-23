import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:profesor_go/app/router.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/widgets/app_scaffold.dart';

void main() {
  Widget app(String initial, {bool homeFallback = true}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: AppRoutes.map,
          builder: (_, _) => const Scaffold(body: Text('MAPA')),
        ),
        GoRoute(
          path: AppRoutes.collection,
          builder: (_, _) => AppScaffold(
            title: 'Profedex',
            homeFallback: homeFallback,
            body: const Text('CONTENIDO'),
          ),
        ),
      ],
    );
    return MaterialApp.router(theme: AppTheme.light(), routerConfig: router);
  }

  testWidgets('without a back stack the fallback arrow returns to the map', (
    tester,
  ) async {
    await tester.pumpWidget(app(AppRoutes.collection));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('MAPA'), findsOneWidget);
  });

  testWidgets('no fallback arrow unless the screen opts in', (tester) async {
    await tester.pumpWidget(app(AppRoutes.collection, homeFallback: false));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('with a back stack the automatic arrow is used', (tester) async {
    await tester.pumpWidget(app(AppRoutes.map));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('MAPA'));
    unawaited(GoRouter.of(context).push(AppRoutes.collection));
    await tester.pumpAndSettle();

    // Flutter's own BackButton, not the fallback one that goes to the map.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('MAPA'), findsOneWidget);
    expect(find.text('CONTENIDO'), findsNothing);
  });
}
