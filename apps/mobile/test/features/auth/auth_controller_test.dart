import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/features/auth/presentation/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'auth_test_utils.dart';

void main() {
  const user = AuthUser(id: 'u1', email: 'ana@uni.edu', displayName: 'Ana');

  late FakeAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = stubbedAuthRepository();
    container = ProviderContainer.test(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
  });

  AuthController notifier() => container.read(authControllerProvider.notifier);
  AuthFormState state() => container.read(authControllerProvider);

  test('starts idle', () {
    expect(state(), const AuthFormState());
    expect(state().loading, isFalse);
    expect(state().error, isNull);
  });

  test('signIn trims the e-mail, toggles loading and ends idle', () async {
    final seen = <AuthFormState>[];
    container.listen(authControllerProvider, (_, next) => seen.add(next));

    final ok = await notifier().signIn('  ana@uni.edu ', '12345678');

    expect(ok, isTrue);
    verify(() => repo.signIn('ana@uni.edu', '12345678')).called(1);
    expect(seen.first.loading, isTrue);
    expect(state(), const AuthFormState());
  });

  test('signIn maps repository errors to a Spanish message', () async {
    when(() => repo.signIn(any(), any()))
        .thenThrow(AppException.fromCode(AppException.invalidCredentials));

    final ok = await notifier().signIn('ana@uni.edu', 'wrong-1');

    expect(ok, isFalse);
    expect(state().loading, isFalse);
    expect(
      state().error,
      AppException.messages[AppException.invalidCredentials],
    );
  });

  test('network failures use the auth-specific no-internet message', () async {
    when(() => repo.signIn(any(), any()))
        .thenThrow(const SocketException('offline'));

    await notifier().signIn('ana@uni.edu', '12345678');

    expect(state().error, AuthController.noInternetMessage);
  });

  test('refuses to start while offline', () async {
    final offline = ProviderContainer.test(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWithValue(false),
      ],
    );

    final ok = await offline
        .read(authControllerProvider.notifier)
        .signIn('ana@uni.edu', '12345678');

    expect(ok, isFalse);
    expect(
      offline.read(authControllerProvider).error,
      AuthController.noInternetMessage,
    );
    verifyNever(() => repo.signIn(any(), any()));
  });

  test('signUp with a session does not sign in again', () async {
    when(() => repo.currentUser).thenReturn(user);

    final ok = await notifier().signUp(
      'ana@uni.edu',
      '12345678',
      displayName: ' Ana ',
    );

    expect(ok, isTrue);
    verify(() => repo.signUp('ana@uni.edu', '12345678', displayName: 'Ana'))
        .called(1);
    verifyNever(() => repo.signIn(any(), any()));
    expect(state(), const AuthFormState());
  });

  test('signUp without a session signs in with the same credentials', () async {
    when(() => repo.currentUser).thenReturn(null);

    final ok = await notifier().signUp(
      'ana@uni.edu',
      '12345678',
      displayName: '',
    );

    expect(ok, isTrue);
    verify(() => repo.signUp('ana@uni.edu', '12345678')).called(1);
    verify(() => repo.signIn('ana@uni.edu', '12345678')).called(1);
  });

  test('signUp pending e-mail confirmation succeeds with a notice', () async {
    when(() => repo.currentUser).thenReturn(null);
    when(() => repo.signIn(any(), any())).thenThrow(
      AppException(
        AppException.serverUnavailable,
        AppException.messages[AppException.serverUnavailable]!,
        cause: const AuthException(
          'Email not confirmed',
          code: 'email_not_confirmed',
        ),
      ),
    );

    final ok = await notifier().signUp('ana@uni.edu', '12345678');

    expect(ok, isTrue);
    expect(state().error, isNull);
    expect(state().notice, AuthController.emailConfirmationMessage);
  });

  test('signUp surfaces e-mail taken', () async {
    when(
      () => repo.signUp(any(), any(), displayName: any(named: 'displayName')),
    ).thenThrow(AppException.fromCode(AppException.emailTaken));

    final ok = await notifier().signUp('ana@uni.edu', '12345678');

    expect(ok, isFalse);
    expect(state().error, AppException.messages[AppException.emailTaken]);
  });

  test(
    'signOut calls the repository and clearMessages resets errors',
    () async {
      when(() => repo.signOut()).thenThrow(Exception('boom'));
      expect(await notifier().signOut(), isFalse);
      expect(state().error, AppException.messages[AppException.unknown]);

      notifier().clearMessages();
      expect(state(), const AuthFormState());

      when(() => repo.signOut()).thenAnswer((_) async {});
      expect(await notifier().signOut(), isTrue);
      verify(() => repo.signOut()).called(2);
    },
  );
}
