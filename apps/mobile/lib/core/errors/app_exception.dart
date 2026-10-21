import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Domain error with a stable [code] and a user-facing Spanish [message].
///
/// Never carries a stack trace into the UI: `toString()` only prints the code
/// and message. The original error (if any) is kept in [cause] for logging.
class AppException implements Exception {
  const AppException(this.code, this.message, {this.cause});

  /// Builds the exception for a known server / client error code, using the
  /// canonical Spanish message. Unknown codes fall back to [unknown].
  factory AppException.fromCode(String code, {Object? cause}) {
    final normalized = code.trim().toUpperCase();
    final message = messages[normalized] ?? messages[unknown]!;
    return AppException(
      messages.containsKey(normalized) ? normalized : unknown,
      message,
      cause: cause,
    );
  }

  /// Maps any thrown object to an [AppException].
  factory AppException.from(Object error) {
    if (error is AppException) return error;

    // Edge Function errors: body is `{ "error": "<CODE>", "message": "..." }`.
    // In functions_client 2.7.x that body is the decoded `details` of a
    // `FunctionsHttpException` (a `Map` for `application/json`, the raw text
    // otherwise) and the HTTP status is `FunctionException.status`.
    // `FunctionsFetchException` (status 0) means the request never left the
    // device, so it must be checked before its supertype.
    if (error is FunctionsFetchException) {
      return AppException.fromCode(noInternet, cause: error);
    }
    if (error is FunctionException) {
      final code = _codeFromFunctionDetails(error.details);
      if (code != null) return AppException.fromCode(code, cause: error);
      return AppException.fromCode(
        _codeForHttpStatus(error.status),
        cause: error,
      );
    }

    if (error is AuthException) return _fromAuth(error);

    if (error is PostgrestException) {
      final code = (error.code ?? '').toUpperCase();
      // PGRST301/PGRST303 = missing/invalid/expired JWT (HTTP 401).
      if (code == '401' || code == 'PGRST301' || code == 'PGRST303') {
        return AppException.fromCode(unauthorized, cause: error);
      }
      // 42501 = row-level-security denial (HTTP 403): the session is valid,
      // the operation is not allowed.
      if (code == '403' || code == '42501') {
        return AppException.fromCode(forbidden, cause: error);
      }
      return AppException.fromCode(serverUnavailable, cause: error);
    }

    if (error is SocketException ||
        error is HttpException ||
        error is HandshakeException) {
      return AppException.fromCode(noInternet, cause: error);
    }
    if (error is TimeoutException) {
      return AppException.fromCode(serverUnavailable, cause: error);
    }
    // package:http ClientException is not imported here on purpose; match by
    // runtime type name to avoid a direct dependency. `IOClient` wraps every
    // transport failure (including SocketException) in one.
    if (_isHttpClientException(error)) {
      return AppException.fromCode(noInternet, cause: error);
    }
    // A malformed / non-JSON payload is a backend problem, not a bug the
    // player can act on.
    if (error is FormatException) {
      return AppException.fromCode(serverUnavailable, cause: error);
    }
    return AppException.fromCode(unknown, cause: error);
  }

  final String code;
  final String message;
  final Object? cause;

  // ---- Error codes -------------------------------------------------------
  // Server codes (CONTRACTS §4)
  static const unauthorized = 'UNAUTHORIZED';
  static const forbidden = 'FORBIDDEN';
  static const tagNotFound = 'TAG_NOT_FOUND';
  static const tagDisabled = 'TAG_DISABLED';
  static const professorDisabled = 'PROFESSOR_DISABLED';
  static const alreadyCaptured = 'ALREADY_CAPTURED';
  static const invalidInput = 'INVALID_INPUT';
  static const encounterNotFound = 'ENCOUNTER_NOT_FOUND';
  static const encounterNotActive = 'ENCOUNTER_NOT_ACTIVE';
  static const encounterExpired = 'ENCOUNTER_EXPIRED';
  // Client-side codes
  static const noInternet = 'NO_INTERNET';
  static const serverUnavailable = 'SERVER_UNAVAILABLE';
  static const nfcUnsupported = 'NFC_UNSUPPORTED';
  static const nfcDisabled = 'NFC_DISABLED';
  static const nfcCancelled = 'NFC_CANCELLED';
  static const nfcReadError = 'NFC_READ_ERROR';
  static const locationDenied = 'LOCATION_DENIED';
  static const locationDisabled = 'LOCATION_DISABLED';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const emailTaken = 'EMAIL_TAKEN';
  static const weakPassword = 'WEAK_PASSWORD';
  static const unknown = 'UNKNOWN';

  /// Canonical user-facing messages (Spanish).
  static const Map<String, String> messages = {
    noInternet: 'Sin conexión. No puedes iniciar una captura sin conexión.',
    serverUnavailable:
        'El servidor no responde ahora mismo. Inténtalo de nuevo en unos segundos.',
    nfcUnsupported: 'Este dispositivo no tiene NFC.',
    nfcDisabled: 'El NFC está desactivado. Actívalo en los ajustes del móvil.',
    nfcCancelled: 'Lectura NFC cancelada.',
    nfcReadError: 'No se pudo leer la tarjeta. Acércala de nuevo al móvil.',
    tagNotFound: 'Esta tarjeta no es válida',
    tagDisabled: 'Esta tarjeta está desactivada.',
    professorDisabled: 'Este profesor no está disponible ahora mismo.',
    alreadyCaptured: 'Ya capturaste a este profesor',
    encounterExpired: 'El encuentro expiró. Vuelve a leer la tarjeta NFC.',
    encounterNotActive:
        'Este encuentro ya terminó. Vuelve a leer la tarjeta NFC.',
    encounterNotFound: 'No encontramos este encuentro. Vuelve a leer la tarjeta.',
    forbidden: 'No tienes permiso para hacer esto.',
    unauthorized: 'Tu sesión ha caducado. Inicia sesión de nuevo.',
    invalidInput: 'Datos no válidos. Inténtalo de nuevo.',
    locationDenied:
        'Sin permiso de ubicación. Puedes seguir jugando, pero no te veremos en el mapa.',
    locationDisabled: 'La ubicación del móvil está desactivada.',
    invalidCredentials: 'Correo o contraseña incorrectos.',
    emailTaken: 'Ya existe una cuenta con ese correo.',
    weakPassword:
        'La contraseña debe tener al menos '
        '${AppConfig.minPasswordLength} caracteres.',
    unknown: 'Algo salió mal. Inténtalo de nuevo.',
  };

  bool get isNoInternet => code == noInternet;
  bool get isUnauthorized => code == unauthorized;

  /// Reads the `{ "error": "<CODE>" }` field of an Edge Function error body.
  /// The body arrives decoded (`Map`) for `application/json`; a body that the
  /// client could not decode arrives as the raw text, so try once more here.
  static String? _codeFromFunctionDetails(Object? details) {
    if (details is Map) {
      final code = details['error'] ?? details['code'];
      if (code is String && code.isNotEmpty && messages.containsKey(code.toUpperCase())) {
        return code;
      }
      return null;
    }
    if (details is String && details.trimLeft().startsWith('{')) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is Map) return _codeFromFunctionDetails(decoded);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// Fallback when an Edge Function error body carries no known code.
  /// Statuses come from CONTRACTS §4; 404/409 are ambiguous there
  /// (TAG_NOT_FOUND vs ENCOUNTER_NOT_FOUND, ALREADY_CAPTURED vs
  /// ENCOUNTER_NOT_ACTIVE), so they stay generic.
  static String _codeForHttpStatus(int status) => switch (status) {
        400 => invalidInput,
        401 => unauthorized,
        403 => forbidden,
        410 => encounterExpired,
        _ => serverUnavailable,
      };

  static bool _isHttpClientException(Object error) =>
      error.runtimeType.toString().contains('ClientException');

  static AppException _fromAuth(AuthException error) {
    final msg = error.message.toLowerCase();
    final code = (error.code ?? '').toLowerCase();
    // gotrue wraps every transport failure (SocketException, ClientException,
    // DNS failure…) in an AuthRetryableFetchException with a null statusCode;
    // with a 5xx statusCode it is the server that is unhappy.
    if (error is AuthRetryableFetchException) {
      final status = int.tryParse(error.statusCode ?? '');
      return AppException(
        status == null ? noInternet : serverUnavailable,
        messages[status == null ? noInternet : serverUnavailable]!,
        cause: error,
      );
    }
    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return AppException(invalidCredentials, messages[invalidCredentials]!,
          cause: error);
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        msg.contains('already registered') ||
        msg.contains('already exists')) {
      return AppException(emailTaken, messages[emailTaken]!, cause: error);
    }
    if (code == 'weak_password' ||
        msg.contains('password should be') ||
        msg.contains('password is too') ||
        msg.contains('password must')) {
      return AppException(weakPassword, messages[weakPassword]!, cause: error);
    }
    if (error.statusCode == '401' ||
        code == 'session_expired' ||
        code == 'session_not_found' ||
        code == 'bad_jwt' ||
        error is AuthSessionMissingException) {
      return AppException(unauthorized, messages[unauthorized]!, cause: error);
    }
    if (msg.contains('socket') || msg.contains('failed host lookup')) {
      return AppException(noInternet, messages[noInternet]!, cause: error);
    }
    return AppException(serverUnavailable, messages[serverUnavailable]!,
        cause: error);
  }

  @override
  String toString() => 'AppException($code): $message';
}
