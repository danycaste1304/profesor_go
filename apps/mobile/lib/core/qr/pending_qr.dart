import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'url_cleanup_stub.dart'
    if (dart.library.html) 'url_cleanup_web.dart'
    as url_cleanup;

/// Keeps a scanned QR through an external Google OAuth round trip.
/// The reusable secret is removed as soon as the encounter starts.
abstract final class PendingQr {
  static const _key = 'pending.professor_qr';
  static final _pattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
  static String? _code;

  static bool get hasCode => _code != null;

  static String? _fromUri(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty) return null;
    final fragment = uri.fragment;
    if (!fragment.startsWith('qr=')) return null;
    final code = fragment.substring(3);
    return _pattern.hasMatch(code) ? code : null;
  }

  static String? parse(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri == null ? null : _fromUri(uri);
  }

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final incoming = kIsWeb && Uri.base.fragment.startsWith('qr=')
        ? Uri.base.fragment.substring(3)
        : null;
    if (incoming != null) {
      // Remove the credential from the visible URL before any navigation.
      url_cleanup.removeQrFragment();
      if (_pattern.hasMatch(incoming)) {
        _code = incoming;
        await prefs.setString(_key, incoming);
      }
    } else {
      final saved = prefs.getString(_key);
      _code = saved != null && _pattern.hasMatch(saved) ? saved : null;
    }
  }

  static Future<void> save(String code) async {
    if (!_pattern.hasMatch(code)) throw ArgumentError('Invalid QR credential');
    _code = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  /// Handles a fragment delivered to an already-running Flutter web app.
  /// GoRouter sees `#qr=...` as the `/qr=...` route on hash-based hosting.
  static Future<bool> saveWebRoute(String code) async {
    if (kIsWeb) url_cleanup.removeQrFragment();
    if (!_pattern.hasMatch(code)) return false;
    await save(code);
    return true;
  }

  static Future<String?> take() async {
    final code = _code;
    _code = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    return code;
  }
}
