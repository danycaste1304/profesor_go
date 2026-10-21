import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/capture.dart';
import '../models/collection_progress.dart';
import '../models/encounter.dart';
import '../models/professor.dart';
import 'demo_seed.dart';

/// In-memory game state shared by the Mock repositories in demo mode.
///
/// Mirrors the server tables (`professors`, `nfc_tags`, `encounters`,
/// `captures`) for a single demo player. Captures are optionally persisted to
/// SharedPreferences so the collection survives an app restart.
class DemoGameState {
  DemoGameState({
    List<Professor>? professors,
    List<DemoTagSeed>? tags,
    this.persist = false,
    DateTime Function()? clock,
    this.userId = 'demo-user',
    this.encounterExpirationSeconds = 180,
  }) : professors = List.of(professors ?? demoProfessors),
       tags = List.of(tags ?? demoTagSeeds),
       _clock = clock ?? DateTime.now;

  static const _prefsKey = 'demo.captures';

  final List<Professor> professors;
  final List<DemoTagSeed> tags;
  final bool persist;
  final String userId;
  final int encounterExpirationSeconds;
  final DateTime Function() _clock;

  final Map<String, Capture> _capturesByProfessor = {};
  final Map<String, Encounter> _encounters = {};
  DateTime? collectionCompletedAt;

  Future<void>? _loading;
  int _sequence = 0;

  DateTime now() => _clock().toUtc();

  /// Loads persisted captures once (no-op when [persist] is false).
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final currentProfessorIds = activeProfessors.map((p) => p.id).toSet();
      final list = decoded['captures'];
      if (list is List) {
        for (final item in list) {
          if (item is Map) {
            final c = Capture.fromJson(item.cast<String, dynamic>());
            if (currentProfessorIds.contains(c.professorId)) {
              _capturesByProfessor[c.professorId] = c;
            }
          }
        }
      }
      final completed = decoded['collection_completed_at'];
      if (completed is String && progress().completed) {
        collectionCompletedAt = DateTime.tryParse(completed);
      }
    } catch (e) {
      debugPrint('DemoGameState: could not load persisted captures: $e');
    }
  }

  Future<void> _save() async {
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'captures': _capturesByProfessor.values
              .map((c) => c.toJson())
              .toList(),
          'collection_completed_at': collectionCompletedAt?.toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('DemoGameState: could not persist captures: $e');
    }
  }

  // ---- Queries -----------------------------------------------------------

  List<Professor> get activeProfessors =>
      professors.where((p) => p.active).toList(growable: false);

  Professor? professorById(String? id) {
    if (id == null) return null;
    for (final p in professors) {
      if (p.id == id) return p;
    }
    return null;
  }

  DemoTagSeed? tagByIdentifier(String identifier) {
    final id = identifier.trim().toUpperCase();
    for (final t in tags) {
      if (t.identifier.toUpperCase() == id) return t;
    }
    return null;
  }

  bool isCaptured(String professorId) =>
      _capturesByProfessor.containsKey(professorId);

  List<Capture> get captures {
    final list = _capturesByProfessor.values.toList();
    list.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return List.unmodifiable(list);
  }

  Encounter? encounterById(String id) => _encounters[id];

  CollectionProgress progress() =>
      CollectionProgress.compute(professors: professors, captures: captures);

  // ---- Mutations ---------------------------------------------------------

  String nextId(String prefix) {
    _sequence++;
    return '$prefix-${now().microsecondsSinceEpoch.toRadixString(36)}-$_sequence';
  }

  /// Marks previous ACTIVE encounters of this professor as EXPIRED and
  /// registers [encounter].
  void putEncounter(Encounter encounter) {
    for (final entry in _encounters.entries.toList()) {
      final e = entry.value;
      if (e.professor.id == encounter.professor.id &&
          e.status == EncounterStatus.active &&
          e.id != encounter.id) {
        _encounters[entry.key] = e.copyWith(status: EncounterStatus.expired);
      }
    }
    _encounters[encounter.id] = encounter;
  }

  void setEncounterStatus(String id, EncounterStatus status) {
    final e = _encounters[id];
    if (e != null) _encounters[id] = e.copyWith(status: status);
  }

  /// Stores a capture (once per professor) and returns the new progress.
  Future<CollectionProgress> addCapture(Capture capture) async {
    _capturesByProfessor.putIfAbsent(capture.professorId, () => capture);
    final p = progress();
    if (p.completed) collectionCompletedAt ??= now();
    await _save();
    return p;
  }

  /// Starts a fresh local demo collection without touching account or cosmetic
  /// preferences. Removing the saved key also survives a cold app restart.
  Future<void> reset() async {
    await ensureLoaded();
    _capturesByProfessor.clear();
    _encounters.clear();
    collectionCompletedAt = null;
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    }
  }
}
