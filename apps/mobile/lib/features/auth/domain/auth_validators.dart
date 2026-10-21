import '../../../core/config/app_config.dart';

/// Pure form validators for the auth screens. They return the Spanish error
/// text to show under the field, or `null` when the value is valid.
abstract final class AuthValidators {
  /// Mirrors the backend policy ([AppConfig.minPasswordLength]).
  static const int minPasswordLength = AppConfig.minPasswordLength;
  static const int maxDisplayNameLength = 24;

  static final RegExp _emailRegExp = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static const String emailRequired = 'Introduce tu correo';
  static const String emailInvalid = 'Correo no válido';
  static const String passwordRequired = 'Introduce tu contraseña';
  static const String passwordTooShort =
      'La contraseña debe tener al menos $minPasswordLength caracteres';
  static const String displayNameTooShort =
      'El apodo debe tener al menos 2 caracteres';
  static const String displayNameTooLong =
      'El apodo es demasiado largo (máximo 24 caracteres)';

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return emailRequired;
    if (!_emailRegExp.hasMatch(v)) return emailInvalid;
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return passwordRequired;
    if (v.length < minPasswordLength) return passwordTooShort;
    return null;
  }

  /// Optional nickname: empty is valid.
  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length < 2) return displayNameTooShort;
    if (v.length > maxDisplayNameLength) return displayNameTooLong;
    return null;
  }
}
