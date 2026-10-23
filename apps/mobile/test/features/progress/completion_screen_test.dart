import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/features/collection/domain/date_format.dart';
import 'package:profesor_go/features/progress/presentation/completion_screen.dart';

import '../collection/fakes.dart';

void main() {
  final completedAt = DateTime.utc(2026, 9, 16, 10, 30);

  FakeProfessorRepository fullRepo() => FakeProfessorRepository(
    captures: [for (final professor in demoProfessors) captureOf(professor.id)],
  );

  Future<void> pumpCompletion(
    WidgetTester tester, {
    required FakeAuthRepository auth,
  }) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      buildCollectionApp(
        repository: fullRepo(),
        auth: auth,
        initialLocation: '/completion',
      ),
    );
    // The confetti loops forever: pump fixed frames instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows the title, completion timestamp and earned achievement', (
    tester,
  ) async {
    final auth = FakeAuthRepository(
      profile: Profile(
        id: 'u1',
        email: 'test@uni.edu',
        collectionCompletedAt: completedAt,
      ),
    );
    await pumpCompletion(tester, auth: auth);

    expect(find.byType(CompletionScreen), findsOneWidget);
    expect(find.text(CompletionScreen.title), findsOneWidget);
    expect(find.text(formatDateTime(completedAt)), findsOneWidget);
    expect(find.text('Completada el'), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('LOGRO DESBLOQUEADO'), findsOneWidget);
    expect(find.text(CompletionScreen.achievementTitle), findsOneWidget);
    expect(find.text('VOLVER AL MAPA'), findsOneWidget);
  });

  testWidgets('does not invent a date when the profile has no timestamp', (
    tester,
  ) async {
    final auth = FakeAuthRepository(
      profile: const Profile(id: 'u1', email: 'test@uni.edu'),
    );
    await pumpCompletion(tester, auth: auth);

    expect(find.text('Completada el'), findsOneWidget);
    expect(find.text('Fecha no disponible'), findsOneWidget);
  });

  testWidgets('survives a profile error and "Volver al mapa" navigates', (
    tester,
  ) async {
    final auth = FakeAuthRepository(profileError: StateError('boom'));
    await pumpCompletion(tester, auth: auth);

    expect(find.text(CompletionScreen.title), findsOneWidget);
    await tester.tap(find.text('VOLVER AL MAPA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('MAP STUB'), findsOneWidget);
    expect(find.byType(CompletionScreen), findsNothing);
  });

  testWidgets('lays out at phone width without overflow', (tester) async {
    final auth = FakeAuthRepository(
      profile: Profile(
        id: 'u1',
        email: 'test@uni.edu',
        collectionCompletedAt: completedAt,
      ),
    );
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      buildCollectionApp(
        repository: fullRepo(),
        auth: auth,
        initialLocation: '/completion',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1500),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(CompletionScreen.achievementTitle), findsOneWidget);
    expect(find.text('VER MI PROFEDEX'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct navigation cannot unlock an incomplete collection', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCollectionApp(
        repository: FakeProfessorRepository(captures: const []),
        initialLocation: '/completion',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Aún quedan profesores por descubrir'), findsOneWidget);
    expect(find.text('LOGRO DESBLOQUEADO'), findsNothing);
    expect(find.text('0 %'), findsOneWidget);
    await tester.tap(find.text('VER PROFEDEX'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CompletionScreen), findsNothing);
  });
}
