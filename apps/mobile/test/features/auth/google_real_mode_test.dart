import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profesor_go/core/config/app_config.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/features/auth/presentation/login_screen.dart';

import 'auth_test_utils.dart';

void main() {
  testWidgets(
    'real build starts Google OAuth without showing password registration',
    (tester) async {
      final repo = stubbedAuthRepository();
      await tester.pumpWidget(
        buildTestApp(
          screen: const LoginScreen(),
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            isOnlineProvider.overrideWithValue(true),
          ],
        ),
      );
      await tester.pump();

      expect(find.byKey(LoginScreen.googleKey), findsOneWidget);
      expect(find.byKey(LoginScreen.emailKey), findsNothing);
      expect(find.byKey(LoginScreen.registerLinkKey), findsNothing);

      await tapVisible(tester, find.byKey(LoginScreen.googleKey));
      await tester.pump();
      verify(() => repo.signInWithGoogle()).called(1);
      expect(
        find.text('Completa el acceso en Google y vuelve a Profesor GO.'),
        findsOneWidget,
      );
    },
    skip: AppConfig.isDemoMode,
  );
}
