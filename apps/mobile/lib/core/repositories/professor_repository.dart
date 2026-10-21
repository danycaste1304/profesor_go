import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/capture.dart';
import '../models/collection_progress.dart';
import '../models/professor.dart';

/// Read access to professors, the player's captures and progress.
abstract class ProfessorRepository {
  /// Active professors, sorted by rarity (legendary first) then name.
  Future<List<Professor>> getActiveProfessors();

  /// The current user's captures.
  Future<List<Capture>> getMyCaptures();

  /// `collection_progress()`.
  Future<CollectionProgress> getProgress();

  /// Last known values (memory + optional SharedPreferences) for offline UI.
  ProfessorCache get cache;
}

/// Last-known-value cache. Memory first; optionally mirrored to
/// SharedPreferences so the collection can be shown without network.
class ProfessorCache {
  ProfessorCache({this.persistent = true});

  static const _kProfessors = 'cache.professors';
  static const _kCaptures = 'cache.captures';
  static const _kProgress = 'cache.progress';

  final bool persistent;

  List<Professor>? _professors;
  List<Capture>? _captures;
  CollectionProgress? _progress;
  Future<void>? _loading;

  List<Professor>? get professors => _professors;
  List<Capture>? get captures => _captures;
  CollectionProgress? get progress => _progress;

  /// Loads persisted values once. Safe to call repeatedly.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    if (!persistent) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = prefs.getString(_kProfessors);
      if (p != null) {
        _professors = (jsonDecode(p) as List)
            .map((e) => Professor.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      final c = prefs.getString(_kCaptures);
      if (c != null) {
        _captures = (jsonDecode(c) as List)
            .map((e) => Capture.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      final g = prefs.getString(_kProgress);
      if (g != null) {
        _progress = CollectionProgress.fromJson(
          (jsonDecode(g) as Map).cast<String, dynamic>(),
        );
      }
    } catch (e) {
      debugPrint('ProfessorCache: could not load cache: $e');
    }
  }

  Future<void> saveProfessors(List<Professor> value) {
    _professors = List.unmodifiable(value);
    return _persist(_kProfessors, value.map((p) => p.toJson()).toList());
  }

  Future<void> saveCaptures(List<Capture> value) {
    _captures = List.unmodifiable(value);
    return _persist(_kCaptures, value.map((c) => c.toJson()).toList());
  }

  Future<void> saveProgress(CollectionProgress value) {
    _progress = value;
    return _persist(_kProgress, value.toJson());
  }

  Future<void> clear() async {
    _professors = null;
    _captures = null;
    _progress = null;
    if (!persistent) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kProfessors);
      await prefs.remove(_kCaptures);
      await prefs.remove(_kProgress);
    } catch (_) {}
  }

  Future<void> _persist(String key, Object json) async {
    if (!persistent) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(json));
    } catch (e) {
      debugPrint('ProfessorCache: could not persist $key: $e');
    }
  }
}

/// Shared ordering: legendary first, then display name.
int compareProfessors(Professor a, Professor b) {
  final byRank = b.rarity.rank.compareTo(a.rarity.rank);
  return byRank != 0 ? byRank : a.displayName.compareTo(b.displayName);
}
