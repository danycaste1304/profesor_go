import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppException.fromCode', () {
    test('maps the contract codes to Spanish messages', () {
      expect(
        AppException.fromCode('TAG_NOT_FOUND').message,
        'Esta tarjeta no es válida',
      );
      expect(
        AppException.fromCode('ALREADY_CAPTURED').message,
        'Ya capturaste a este profesor',
      );
      expect(
        AppException.fromCode('ENCOUNTER_EXPIRED').message,
        'El encuentro expiró. Vuelve a leer la tarjeta NFC.',
      );
      expect(
        AppException.fromCode('NO_INTERNET').message,
        'Sin conexión. No puedes iniciar una captura sin conexión.',
      );
      for (final code in [
        'TAG_DISABLED',
        'PROFESSOR_DISABLED',
        'ENCOUNTER_NOT_ACTIVE',
        'UNAUTHORIZED',
        'SERVER_UNAVAILABLE',
        'NFC_UNSUPPORTED',
        'NFC_DISABLED',
      ]) {
        final e = AppException.fromCode(code);
        expect(e.code, code);
        expect(e.message, isNotEmpty);
      }
    });

    test('is tolerant of case and falls back to UNKNOWN', () {
      expect(AppException.fromCode('tag_not_found').code, 'TAG_NOT_FOUND');
      final e = AppException.fromCode('SOMETHING_NEW');
      expect(e.code, AppException.unknown);
      expect(e.message, AppException.messages[AppException.unknown]);
    });
  });

  group('AppException.from', () {
    test('returns the same instance for AppException', () {
      final e = AppException.fromCode(AppException.tagDisabled);
      expect(identical(AppException.from(e), e), isTrue);
    });

    test('maps Edge Function error bodies by their "error" code', () {
      final e = AppException.from(
        const FunctionsHttpException(
          status: 409,
          details: {'error': 'ALREADY_CAPTURED', 'message': 'dup'},
        ),
      );
      expect(e.code, 'ALREADY_CAPTURED');
      expect(e.message, 'Ya capturaste a este profesor');
    });

    test('maps 401 without body to UNAUTHORIZED and others to server error', () {
      expect(
        AppException.from(const FunctionsHttpException(status: 401)).code,
        AppException.unauthorized,
      );
      expect(
        AppException.from(
          const FunctionsHttpException(status: 500, details: 'boom'),
        ).code,
        AppException.serverUnavailable,
      );
    });

    test('maps transport failures to NO_INTERNET', () {
      expect(
        AppException.from(const FunctionsFetchException(details: 'x')).code,
        AppException.noInternet,
      );
      expect(
        AppException.from(const SocketException('down')).code,
        AppException.noInternet,
      );
    });

    test('maps timeouts to SERVER_UNAVAILABLE', () {
      expect(
        AppException.from(TimeoutException('slow')).code,
        AppException.serverUnavailable,
      );
    });

    test('maps auth errors', () {
      expect(
        AppException.from(const AuthException('Invalid login credentials')).code,
        AppException.invalidCredentials,
      );
      expect(
        AppException.from(
          const AuthException('User already registered', statusCode: '422'),
        ).code,
        AppException.emailTaken,
      );
    });

    test('maps Postgrest JWT errors to UNAUTHORIZED', () {
      expect(
        AppException.from(
          const PostgrestException(message: 'JWT expired', code: 'PGRST301'),
        ).code,
        AppException.unauthorized,
      );
      expect(
        AppException.from(const PostgrestException(message: 'oops')).code,
        AppException.serverUnavailable,
      );
    });

    test('falls back to the HTTP status when the body carries no code', () {
      // CONTRACTS §4 statuses, as returned by the live Edge Functions.
      expect(
        AppException.from(const FunctionsHttpException(status: 400)).code,
        AppException.invalidInput,
      );
      expect(
        AppException.from(const FunctionsHttpException(status: 403)).code,
        AppException.forbidden,
      );
      expect(
        AppException.from(const FunctionsHttpException(status: 410)).code,
        AppException.encounterExpired,
      );
      // 404 / 409 are ambiguous in the contract, so they stay generic.
      expect(
        AppException.from(const FunctionsHttpException(status: 409)).code,
        AppException.serverUnavailable,
      );
    });

    test('decodes an error body that arrived as raw text', () {
      final e = AppException.from(
        const FunctionsHttpException(
          status: 410,
          details: '{"error":"ENCOUNTER_EXPIRED","message":"expiro"}',
        ),
      );
      expect(e.code, AppException.encounterExpired);
      expect(e.message, 'El encuentro expiró. Vuelve a leer la tarjeta NFC.');
    });

    test('an unknown server code falls back to the status, not UNKNOWN', () {
      expect(
        AppException.from(
          const FunctionsHttpException(
            status: 403,
            details: {'error': 'SOME_NEW_CODE'},
          ),
        ).code,
        AppException.forbidden,
      );
    });

    test('maps every live start-encounter / resolve-capture error body', () {
      // Bodies copied verbatim from the running backend.
      const live = <int, Map<String, String>>{
        404: {'error': 'TAG_NOT_FOUND', 'message': 'Este tag NFC no...'},
        403: {'error': 'TAG_DISABLED', 'message': 'Este tag NFC esta...'},
        409: {'error': 'ALREADY_CAPTURED', 'message': 'Ya tienes...'},
        400: {'error': 'INVALID_INPUT', 'message': 'El campo...'},
        401: {'error': 'UNAUTHORIZED', 'message': 'Necesitas...'},
        410: {'error': 'ENCOUNTER_EXPIRED', 'message': 'El encuentro...'},
      };
      live.forEach((status, body) {
        final e = AppException.from(
          FunctionsHttpException(status: status, details: body),
        );
        expect(e.code, body['error']);
        expect(e.message, AppException.messages[body['error']]);
      });
      expect(
        AppException.from(
          const FunctionsHttpException(
            status: 403,
            details: {'error': 'FORBIDDEN'},
          ),
        ).code,
        AppException.forbidden,
      );
      expect(
        AppException.from(
          const FunctionsHttpException(
            status: 404,
            details: {'error': 'ENCOUNTER_NOT_FOUND'},
          ),
        ).code,
        AppException.encounterNotFound,
      );
      expect(
        AppException.from(
          const FunctionsHttpException(
            status: 409,
            details: {'error': 'ENCOUNTER_NOT_ACTIVE'},
          ),
        ).code,
        AppException.encounterNotActive,
      );
    });

    test('maps the Postgrest codes the live REST API returns', () {
      // 401 + PGRST301 -> the session is gone.
      expect(
        AppException.from(
          const PostgrestException(
            message: 'JWT cryptographic operation failed',
            code: 'PGRST301',
          ),
        ).code,
        AppException.unauthorized,
      );
      // 403 + 42501 -> RLS said no; the session is fine.
      expect(
        AppException.from(
          const PostgrestException(
            message: 'new row violates row-level security policy',
            code: '42501',
          ),
        ).code,
        AppException.forbidden,
      );
      // 404 + PGRST205 -> schema problem, nothing the player can do.
      expect(
        AppException.from(
          const PostgrestException(
            message: "Could not find the table 'public.nope'",
            code: 'PGRST205',
          ),
        ).code,
        AppException.serverUnavailable,
      );
    });

    test('maps gotrue transport failures to NO_INTERNET', () {
      expect(
        AppException.from(
          AuthRetryableFetchException(
            message: 'ClientException with SocketException: Connection refused',
          ),
        ).code,
        AppException.noInternet,
      );
      // ... but a 5xx retryable response is the server, not the phone.
      expect(
        AppException.from(
          AuthRetryableFetchException(message: 'boom', statusCode: '503'),
        ).code,
        AppException.serverUnavailable,
      );
      expect(
        AppException.from(AuthSessionMissingException()).code,
        AppException.unauthorized,
      );
    });

    test('maps a malformed payload to SERVER_UNAVAILABLE', () {
      expect(
        AppException.from(const FormatException('not json')).code,
        AppException.serverUnavailable,
      );
    });

    test('never leaks stack traces or raw errors in toString', () {
      final e = AppException.from(StateError('internal secret detail'));
      expect(e.code, AppException.unknown);
      expect(e.toString(), isNot(contains('internal secret detail')));
      expect(e.toString(), isNot(contains('#0')));
      expect(e.cause, isA<StateError>());
    });
  });
}
