import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../errors/app_exception.dart';
import '../mock/demo_game_state.dart';
import '../models/auth_user.dart';
import '../models/profile.dart';
import 'auth_repository.dart';

/// [AuthRepository] that accepts any e-mail / password.
///
/// The session (and the display names given at sign-up) are kept in
/// SharedPreferences when [persist] is true so the app stays logged in.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({
    this.persist = false,
    this._gameState,
    this.delay = const Duration(milliseconds: 300),
  });

  static const _kUser = 'demo.auth.user';
  static const _kNames = 'demo.auth.names';

  final bool persist;
  final Duration delay;
  final DemoGameState? _gameState;
  final Map<String, String> _displayNames = {};
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  AuthUser? _current;
  Future<void>? _loading;

  Future<void> _ready() => _loading ??= _load();

  Future<void> _load() async {
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kUser);
      if (raw != null) {
        _current = AuthUser.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>(),
        );
      }
      final names = prefs.getString(_kNames);
      if (names != null) {
        (jsonDecode(names) as Map).forEach((k, v) {
          if (k is String && v is String) _displayNames[k] = v;
        });
      }
    } catch (e) {
      debugPrint('MockAuthRepository: could not load session: $e');
    }
  }

  Future<void> _save() async {
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _current;
      if (user == null) {
        await prefs.remove(_kUser);
      } else {
        await prefs.setString(_kUser, jsonEncode(user.toJson()));
      }
      await prefs.setString(_kNames, jsonEncode(_displayNames));
    } catch (e) {
      debugPrint('MockAuthRepository: could not persist session: $e');
    }
  }

  @override
  Stream<AuthUser?> authState() async* {
    await _ready();
    yield _current;
    yield* _controller.stream;
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<void> signIn(String email, String password) async {
    await _ready();
    final e = _normalize(email);
    if (e.isEmpty || !e.contains('@') || password.isEmpty) {
      throw AppException.fromCode(AppException.invalidCredentials);
    }
    await _wait();
    _setUser(AuthUser(id: _idFor(e), email: e, displayName: _displayNames[e]));
    await _save();
  }

  @override
  Future<void> signInWithGoogle() =>
      signIn('player@profesorgo.local', 'player12345');

  @override
  Future<void> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    await _ready();
    final e = _normalize(email);
    if (e.isEmpty || !e.contains('@')) {
      throw AppException.fromCode(AppException.invalidInput);
    }
    if (password.length < AppConfig.minPasswordLength) {
      throw AppException.fromCode(AppException.weakPassword);
    }
    await _wait();
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) _displayNames[e] = name;
    _setUser(AuthUser(id: _idFor(e), email: e, displayName: _displayNames[e]));
    await _save();
  }

  @override
  Future<void> signOut() async {
    await _ready();
    _setUser(null);
    await _save();
  }

  @override
  Future<Profile?> getProfile() async {
    await _ready();
    final user = _current;
    if (user == null) return null;
    await _gameState?.ensureLoaded();
    return Profile(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      role: user.email == 'admin@profesorgo.local'
          ? UserRole.admin
          : UserRole.player,
      createdAt: DateTime.now().toUtc(),
      collectionCompletedAt: _gameState?.collectionCompletedAt,
    );
  }

  void _setUser(AuthUser? user) {
    _current = user;
    if (!_controller.isClosed) _controller.add(user);
  }

  Future<void> _wait() =>
      delay > Duration.zero ? Future<void>.delayed(delay) : Future.value();

  static String _normalize(String email) => email.trim().toLowerCase();

  static String _idFor(String email) =>
      'demo-${email.hashCode.toRadixString(16)}';

  Future<void> dispose() => _controller.close();
}
