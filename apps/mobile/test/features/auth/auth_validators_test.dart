import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/config/app_config.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/features/auth/domain/auth_validators.dart';

void main() {
  group('AuthValidators.email', () {
    test('rejects empty and malformed values', () {
      expect(AuthValidators.email(null), AuthValidators.emailRequired);
      expect(AuthValidators.email('   '), AuthValidators.emailRequired);
      expect(AuthValidators.email('ana'), AuthValidators.emailInvalid);
      expect(AuthValidators.email('ana@'), AuthValidators.emailInvalid);
      expect(AuthValidators.email('ana@uni'), AuthValidators.emailInvalid);
      expect(AuthValidators.email('a na@uni.edu'), AuthValidators.emailInvalid);
    });

    test('accepts valid addresses (trimmed)', () {
      expect(AuthValidators.email('ana@uni.edu'), isNull);
      expect(AuthValidators.email('  player@profesorgo.local '), isNull);
    });
  });

  group('AuthValidators.password', () {
    test('requires at least 8 characters (the GoTrue minimum)', () {
      expect(AuthValidators.password(null), AuthValidators.passwordRequired);
      expect(AuthValidators.password(''), AuthValidators.passwordRequired);
      expect(AuthValidators.password('12345'), AuthValidators.passwordTooShort);
      // 6 and 7 characters used to pass the form and then be rejected by the
      // server with `weak_password`: the registration dead-end.
      expect(
        AuthValidators.password('123456'),
        AuthValidators.passwordTooShort,
      );
      expect(
        AuthValidators.password('1234567'),
        AuthValidators.passwordTooShort,
      );
      expect(AuthValidators.password('12345678'), isNull);
    });

    test('never accepts a password the backend would reject', () {
      // supabase/config.toml -> [auth] minimum_password_length = 8.
      expect(AppConfig.minPasswordLength, 8);
      expect(AuthValidators.minPasswordLength, AppConfig.minPasswordLength);
      final shortest = '1' * (AppConfig.minPasswordLength - 1);
      expect(AuthValidators.password(shortest), AuthValidators.passwordTooShort);
      expect(AuthValidators.password('${shortest}1'), isNull);
    });

    test('every Spanish string names the same minimum', () {
      const minimum = '${AppConfig.minPasswordLength} caracteres';
      expect(AuthValidators.passwordTooShort, contains(minimum));
      expect(
        AppException.messages[AppException.weakPassword],
        contains(minimum),
      );
    });
  });

  group('AuthValidators.displayName', () {
    test('is optional but bounded', () {
      expect(AuthValidators.displayName(null), isNull);
      expect(AuthValidators.displayName('  '), isNull);
      expect(
        AuthValidators.displayName('A'),
        AuthValidators.displayNameTooShort,
      );
      expect(AuthValidators.displayName('Ana'), isNull);
      expect(
        AuthValidators.displayName('x' * 25),
        AuthValidators.displayNameTooLong,
      );
    });
  });
}
