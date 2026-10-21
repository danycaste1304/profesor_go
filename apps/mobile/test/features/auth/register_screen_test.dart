import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/features/auth/domain/auth_validators.dart';
import 'package:profesor_go/features/auth/presentation/register_screen.dart';

import 'auth_test_utils.dart';

void main() {
  const user = AuthUser(id: 'u1', email: 'ana@uni.edu');
  late FakeAuthRepository repo;

  setUp(() => repo = stubbedAuthRepository());

  Future<void> pumpRegister(WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(
        screen: const RegisterScreen(),
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await tester.pump();
  }

  Future<void> tapSubmit(WidgetTester tester) =>
      tapVisible(tester, find.byKey(RegisterScreen.submitKey));

  testWidgets('renders the three fields and the button', (tester) async {
    await pumpRegister(tester);

    expect(find.text('CREAR CUENTA'), findsNWidgets(2)); // app bar + button
    expect(find.byKey(RegisterScreen.emailKey), findsOneWidget);
    expect(find.byKey(RegisterScreen.passwordKey), findsOneWidget);
    expect(find.byKey(RegisterScreen.displayNameKey), findsOneWidget);
    expect(find.text('¿Ya tienes cuenta? Iniciar sesión'), findsOneWidget);
  });

  testWidgets('validates e-mail, password and nickname before submitting', (
    tester,
  ) async {
    await pumpRegister(tester);

    await tapSubmit(tester);
    expect(find.text(AuthValidators.emailRequired), findsOneWidget);
    expect(find.text(AuthValidators.passwordRequired), findsOneWidget);

    await tester.enterText(find.byKey(RegisterScreen.emailKey), 'nope');
    await tester.enterText(find.byKey(RegisterScreen.passwordKey), '12345');
    await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'A');
    await tapSubmit(tester);

    expect(find.text(AuthValidators.emailInvalid), findsOneWidget);
    expect(find.text(AuthValidators.passwordTooShort), findsOneWidget);
    expect(find.text(AuthValidators.displayNameTooShort), findsOneWidget);
    verifyNever(
      () => repo.signUp(any(), any(), displayName: any(named: 'displayName')),
    );
  });

  testWidgets('valid data calls signUp with the nickname and confirms', (
    tester,
  ) async {
    when(() => repo.currentUser).thenReturn(user);
    await pumpRegister(tester);
    await tester.enterText(find.byKey(RegisterScreen.emailKey), 'ana@uni.edu');
    await tester.enterText(find.byKey(RegisterScreen.passwordKey), '12345678');
    await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'Ana');

    await tapSubmit(tester);
    await tester.pump();

    verify(() => repo.signUp('ana@uni.edu', '12345678', displayName: 'Ana'))
        .called(1);
    expect(find.text(RegisterScreen.createdMessage), findsOneWidget);
  });

  testWidgets('nickname is optional (sent as null)', (tester) async {
    when(() => repo.currentUser).thenReturn(user);
    await pumpRegister(tester);
    await tester.enterText(find.byKey(RegisterScreen.emailKey), 'ana@uni.edu');
    await tester.enterText(find.byKey(RegisterScreen.passwordKey), '12345678');

    await tapSubmit(tester);
    await tester.pump();

    verify(() => repo.signUp('ana@uni.edu', '12345678')).called(1);
  });

  testWidgets('e-mail already taken shows the error banner', (tester) async {
    when(
      () => repo.signUp(any(), any(), displayName: any(named: 'displayName')),
    ).thenThrow(AppException.fromCode(AppException.emailTaken));
    await pumpRegister(tester);
    await tester.enterText(find.byKey(RegisterScreen.emailKey), 'ana@uni.edu');
    await tester.enterText(find.byKey(RegisterScreen.passwordKey), '12345678');

    await tapSubmit(tester);
    await tester.pump();

    expect(
      find.text(AppException.messages[AppException.emailTaken]!),
      findsOneWidget,
    );
    expect(find.text(RegisterScreen.createdMessage), findsNothing);
  });

  testWidgets('login link navigates to /login', (tester) async {
    await pumpRegister(tester);

    await tapVisible(tester, find.byKey(RegisterScreen.loginLinkKey));
    await tester.pumpAndSettle();

    expect(find.text(routeMarkers['/login']!), findsOneWidget);
  });
}
