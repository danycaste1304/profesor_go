import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/features/auth/domain/auth_validators.dart';
import 'package:profesor_go/features/auth/presentation/login_screen.dart';

import 'auth_test_utils.dart';

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = stubbedAuthRepository());

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(
        screen: const LoginScreen(),
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await tester.pump();
  }

  Future<void> tapSubmit(WidgetTester tester) =>
      tapVisible(tester, find.byKey(LoginScreen.submitKey));

  testWidgets('renders logo, fields, button, register link and demo hint', (
    tester,
  ) async {
    await pumpLogin(tester);

    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.text('Profesor GO'), findsOneWidget);
    expect(find.byKey(LoginScreen.emailKey), findsOneWidget);
    expect(find.byKey(LoginScreen.passwordKey), findsOneWidget);
    expect(find.text('ENTRAR'), findsOneWidget);
    expect(find.text('¿No tienes cuenta? Crear cuenta'), findsOneWidget);
    // DEMO_MODE defaults to true in tests.
    expect(find.text(LoginScreen.demoHint), findsOneWidget);
  });

  testWidgets('empty form shows validation errors and never calls signIn', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tapSubmit(tester);

    expect(find.text(AuthValidators.emailRequired), findsOneWidget);
    expect(find.text(AuthValidators.passwordRequired), findsOneWidget);
    verifyNever(() => repo.signIn(any(), any()));
  });

  testWidgets('invalid e-mail and short password are rejected', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.byKey(LoginScreen.emailKey), 'ana@');
    await tester.enterText(find.byKey(LoginScreen.passwordKey), '123');

    await tapSubmit(tester);

    expect(find.text(AuthValidators.emailInvalid), findsOneWidget);
    expect(find.text(AuthValidators.passwordTooShort), findsOneWidget);
    verifyNever(() => repo.signIn(any(), any()));
  });

  testWidgets('valid credentials call signIn with the typed values', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.enterText(find.byKey(LoginScreen.emailKey), 'ana@uni.edu');
    await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret12');

    await tapSubmit(tester);
    await tester.pump();

    verify(() => repo.signIn('ana@uni.edu', 'secret12')).called(1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows a loading state while signIn is pending', (tester) async {
    final pending = Completer<void>();
    when(() => repo.signIn(any(), any())).thenAnswer((_) => pending.future);
    await pumpLogin(tester);
    await tester.enterText(find.byKey(LoginScreen.emailKey), 'ana@uni.edu');
    await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret12');

    await tapSubmit(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('wrong credentials show the Spanish error banner', (
    tester,
  ) async {
    when(() => repo.signIn(any(), any()))
        .thenThrow(AppException.fromCode(AppException.invalidCredentials));
    await pumpLogin(tester);
    await tester.enterText(find.byKey(LoginScreen.emailKey), 'ana@uni.edu');
    await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret12');

    await tapSubmit(tester);
    await tester.pump();

    expect(
      find.text(AppException.messages[AppException.invalidCredentials]!),
      findsOneWidget,
    );
    // No stack trace / exception text leaks into the UI.
    expect(find.textContaining('AppException'), findsNothing);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pump();
    expect(
      find.text(AppException.messages[AppException.invalidCredentials]!),
      findsNothing,
    );
  });

  testWidgets('demo shortcut fills the demo player credentials', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(LoginScreen.demoFillKey));
    await tester.pump();
    await tapSubmit(tester);
    await tester.pump();

    verify(() => repo.signIn(LoginScreen.demoEmail, LoginScreen.demoPassword))
        .called(1);
  });

  testWidgets('register link navigates to /register', (tester) async {
    await pumpLogin(tester);

    await tapVisible(tester, find.byKey(LoginScreen.registerLinkKey));
    await tester.pumpAndSettle();

    expect(find.text(routeMarkers['/register']!), findsOneWidget);
  });
}
