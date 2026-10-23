import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profesor_go/app/router.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/mock/demo_game_state.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/repositories/mock_professor_repository.dart';
import 'package:profesor_go/features/avatar/avatar_style.dart';
import 'package:profesor_go/features/map/presentation/widgets/avatar.dart';
import 'package:profesor_go/features/profile/presentation/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_test_utils.dart';

void main() {
  const user = AuthUser(id: 'u1', email: 'ana@uni.edu', displayName: 'Ana');
  const profile = Profile(id: 'u1', email: 'ana@uni.edu', displayName: 'Ana');
  const progress = CollectionProgress(captured: 3, total: 8, completed: false);

  late FakeAuthRepository repo;
  late FakeProfessorRepository professors;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = stubbedAuthRepository(user: user, profile: profile);
    professors = FakeProfessorRepository();
    when(() => professors.getProgress()).thenAnswer((_) async => progress);
  });

  Future<void> pumpProfile(
    WidgetTester tester, {
    Profile? withProfile,
    CollectionProgress withProgress = progress,
    MockProfessorRepository? mockRepo,
  }) async {
    if (withProfile != null) {
      when(() => repo.getProfile()).thenAnswer((_) async => withProfile);
    }
    await tester.pumpWidget(
      buildTestApp(
        screen: const ProfileScreen(),
        path: AppRoutes.profile,
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          if (mockRepo != null)
            professorRepositoryProvider.overrideWithValue(mockRepo)
          else ...[
            professorRepositoryProvider.overrideWithValue(professors),
            collectionProgressProvider.overrideWith(
              (ref) async => withProgress,
            ),
          ],
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  testWidgets('shows display name, e-mail, progress, demo badge and version', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text('PERFIL'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('ana@uni.edu'), findsOneWidget);
    expect(find.text('MODO DEMO'), findsOneWidget);
    expect(find.text('ADMIN'), findsNothing);
    await scrollTo(tester, find.text('38 %'));
    expect(find.text('38 %'), findsOneWidget);
    expect(find.text('Profesores capturados'), findsOneWidget);
    await scrollTo(tester, find.text('Profesor GO v$kAppVersion'));
    expect(find.text('Profesor GO v$kAppVersion'), findsOneWidget);
    expect(find.text('CERRAR SESIÓN'), findsOneWidget);
  });

  testWidgets('customizes the same player avatar shown on the map', (
    tester,
  ) async {
    await pumpProfile(tester);

    await tapVisible(tester, find.byKey(const Key('avatar_hair_curls')));
    await tapVisible(tester, find.byKey(const Key('avatar_outfit_pink')));
    await tapVisible(tester, find.byKey(const Key('avatar_accessory_glasses')));
    await tester.pumpAndSettle();

    final preview = tester.widget<PixelAvatar>(
      find.descendant(
        of: find.byKey(ProfileScreen.avatarPreviewKey),
        matching: find.byType(PixelAvatar),
      ),
    );
    expect(
      preview.style,
      const AvatarStyle(
        hair: AvatarHair.curls,
        outfit: AvatarOutfit.pink,
        accessory: AvatarAccessory.glasses,
      ),
    );
    expect(
      tester.widget<PixelAvatar>(find.byType(PixelAvatar).first).style,
      preview.style,
    );
  });

  testWidgets('surprise button shows a new look in the profile preview', (
    tester,
  ) async {
    await pumpProfile(tester);
    final before = tester
        .widget<PixelAvatar>(
          find.descendant(
            of: find.byKey(ProfileScreen.avatarPreviewKey),
            matching: find.byType(PixelAvatar),
          ),
        )
        .style;

    await scrollTo(tester, find.byKey(ProfileScreen.avatarSurpriseKey));
    await tapVisible(tester, find.byKey(ProfileScreen.avatarSurpriseKey));
    await tester.pumpAndSettle();

    final after = tester
        .widget<PixelAvatar>(
          find.descendant(
            of: find.byKey(ProfileScreen.avatarPreviewKey),
            matching: find.byType(PixelAvatar),
          ),
        )
        .style;
    expect(after, isNot(before));
  });

  testWidgets('falls back to the e-mail local part without a display name', (
    tester,
  ) async {
    await pumpProfile(
      tester,
      withProfile: const Profile(id: 'u1', email: 'ana@uni.edu'),
    );

    expect(find.text('ana'), findsOneWidget);
    expect(find.text('ana@uni.edu'), findsOneWidget);
  });

  testWidgets('shows the admin badge for admins', (tester) async {
    await pumpProfile(
      tester,
      withProfile: profile.copyWith(role: UserRole.admin),
    );

    expect(find.text('ADMIN'), findsOneWidget);
  });

  testWidgets('shows the completed message when the collection is done', (
    tester,
  ) async {
    await pumpProfile(
      tester,
      withProgress: const CollectionProgress(
        captured: 8,
        total: 8,
        completed: true,
      ),
    );

    await scrollTo(tester, find.text('100 %'));
    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('¡Profedex completa!'), findsOneWidget);
  });

  testWidgets('logout calls signOut on the repository', (tester) async {
    await pumpProfile(tester);

    await scrollTo(tester, find.byKey(ProfileScreen.logoutKey));
    await tapVisible(tester, find.byKey(ProfileScreen.logoutKey));

    verify(() => repo.signOut()).called(1);
  });

  testWidgets('"Ver Profedex" navigates to /collection', (tester) async {
    await pumpProfile(tester);

    await scrollTo(tester, find.byKey(ProfileScreen.collectionKey));
    await tapVisible(tester, find.byKey(ProfileScreen.collectionKey));
    await tester.pumpAndSettle();

    expect(find.text(routeMarkers[AppRoutes.collection]!), findsOneWidget);
  });

  testWidgets('demo reset is hidden when the repository is not the mock', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.byKey(ProfileScreen.resetDemoKey), findsNothing);
    expect(find.text('OPCIONES DE DEMO'), findsNothing);
  });

  testWidgets('demo reset asks first and refreshes the Profedex', (
    tester,
  ) async {
    final state = DemoGameState();
    await state.addCapture(
      Capture(
        id: 'c1',
        userId: state.userId,
        professorId: demoProfessors.first.id,
        throwQuality: ThrowQuality.great,
        capturedAt: DateTime.utc(2026, 9, 16),
      ),
    );
    final mockRepo = MockProfessorRepository(state, delay: Duration.zero);
    await pumpProfile(tester, mockRepo: mockRepo);
    await tester.pump();

    await scrollTo(tester, find.text('OPCIONES DE DEMO'));
    expect(find.text('OPCIONES DE DEMO'), findsOneWidget);

    await tapVisible(tester, find.byKey(ProfileScreen.resetDemoKey));
    expect(find.text('¿Reiniciar la Profedex?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(state.captures, hasLength(1));

    await tapVisible(tester, find.byKey(ProfileScreen.resetDemoKey));
    await tester.tap(find.text('Reiniciar'));
    await tester.pump();

    expect(state.captures, isEmpty);
    expect(find.text('Profedex demo reiniciada'), findsOneWidget);
    await scrollTo(tester, find.text('0 %'));
    expect(find.text('0 %'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
