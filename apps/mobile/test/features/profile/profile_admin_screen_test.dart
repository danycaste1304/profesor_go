import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profesor_go/app/router.dart';
import 'package:profesor_go/core/config/app_config.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/features/profile/presentation/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_test_utils.dart';

void main() {
  const ownerId = '37b8f998-df0e-454e-bc4d-76714e0ad9dc';
  const ownerEmail = 'danycaste1304@gmail.com';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakeProfessorRepository> pumpProfile(
    WidgetTester tester, {
    required AuthUser user,
    required Profile profile,
  }) async {
    final auth = stubbedAuthRepository(user: user, profile: profile);
    final professors = FakeProfessorRepository();
    when(() => professors.resetMyCollection()).thenAnswer((_) async {});
    await tester.pumpWidget(
      buildTestApp(
        screen: const ProfileScreen(),
        path: AppRoutes.profile,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          currentUserProvider.overrideWith((ref) => user),
          profileProvider.overrideWith((ref) async => profile),
          professorRepositoryProvider.overrideWithValue(professors),
          collectionProgressProvider.overrideWith(
            (ref) async => const CollectionProgress(
              captured: 1,
              total: 10,
              completed: false,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return professors;
  }

  testWidgets(
    'only the owner sees the admin reset and confirmation precedes the call',
    (tester) async {
      final professors = await pumpProfile(
        tester,
        user: const AuthUser(id: ownerId, email: ownerEmail),
        profile: const Profile(
          id: ownerId,
          email: ownerEmail,
          role: UserRole.admin,
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(ProfileScreen.resetAdminKey),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tapVisible(tester, find.byKey(ProfileScreen.resetAdminKey));
      await tester.pumpAndSettle();
      expect(find.text('¿Reiniciar la Profedex?'), findsOneWidget);
      verifyNever(() => professors.resetMyCollection());

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      verifyNever(() => professors.resetMyCollection());

      await tapVisible(tester, find.byKey(ProfileScreen.resetAdminKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reiniciar'));
      await tester.pump();
      verify(() => professors.resetMyCollection()).called(1);
      expect(find.text('Tu Profedex fue reiniciada'), findsOneWidget);
    },
    skip: AppConfig.isDemoMode,
  );

  testWidgets('another admin does not see the owner reset', (tester) async {
    await pumpProfile(
      tester,
      user: const AuthUser(id: 'other-admin', email: 'other@test.local'),
      profile: const Profile(
        id: 'other-admin',
        email: 'other@test.local',
        role: UserRole.admin,
      ),
    );
    expect(find.byKey(ProfileScreen.resetAdminKey), findsNothing);
  }, skip: AppConfig.isDemoMode);

  testWidgets('owner without admin role does not see reset', (tester) async {
    await pumpProfile(
      tester,
      user: const AuthUser(id: ownerId, email: ownerEmail),
      profile: const Profile(id: ownerId, email: ownerEmail),
    );
    expect(find.byKey(ProfileScreen.resetAdminKey), findsNothing);
  }, skip: AppConfig.isDemoMode);
}
