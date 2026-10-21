import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';
import '../models/capture.dart';
import '../models/collection_progress.dart';
import '../models/professor.dart';
import 'professor_repository.dart';

/// [ProfessorRepository] over Supabase tables + `collection_progress()` RPC.
///
/// Verified against the live backend (CONTRACTS §2/§3):
/// * `GET /rest/v1/professors` → rows with `id, name, display_name,
///   description (nullable), rarity (upper-case), sprite_url (nullable),
///   active, base_capture_rate (JSON number), created_at, updated_at`.
///   RLS already limits the list to `active = true` for players; the explicit
///   `.eq('active', true)` keeps it correct for an admin account too.
/// * `GET /rest/v1/captures` → rows with `id, user_id, professor_id,
///   encounter_id, throw_quality, captured_at`. RLS limits a *player* to its
///   own rows but an **admin sees every row**, so the user id is filtered
///   explicitly here.
/// * `POST /rest/v1/rpc/collection_progress` → a single jsonb object
///   `{"total": 8, "captured": 0, "completed": false}` (decoded as a `Map`,
///   not a list).
///
/// Only connectivity failures fall back to the cached last-known state; an
/// expired session or a permission error is surfaced so the UI can react.
class SupabaseProfessorRepository implements ProfessorRepository {
  SupabaseProfessorRepository(this._client, {ProfessorCache? cache})
      : cache = cache ?? ProfessorCache();

  final SupabaseClient _client;

  @override
  final ProfessorCache cache;

  @override
  Future<List<Professor>> getActiveProfessors() async {
    await cache.ensureLoaded();
    try {
      final rows = await _client.from('professors').select().eq('active', true);
      final list = rows
          .map((r) => Professor.fromJson(r.cast<String, dynamic>()))
          .toList()
        ..sort(compareProfessors);
      await cache.saveProfessors(list);
      return list;
    } catch (e) {
      return _orCache(e, cache.professors, 'professors');
    }
  }

  @override
  Future<List<Capture>> getMyCaptures() async {
    await cache.ensureLoaded();
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw AppException.fromCode(AppException.unauthorized);
    }
    try {
      final rows = await _client
          .from('captures')
          .select()
          .eq('user_id', userId)
          .order('captured_at', ascending: true);
      final list = rows
          .map((r) => Capture.fromJson(r.cast<String, dynamic>()))
          .toList();
      await cache.saveCaptures(list);
      return list;
    } catch (e) {
      return _orCache(e, cache.captures, 'captures');
    }
  }

  @override
  Future<CollectionProgress> getProgress() async {
    await cache.ensureLoaded();
    try {
      final dynamic data = await _client.rpc<dynamic>('collection_progress');
      final progress = _parseProgress(data);
      await cache.saveProgress(progress);
      return progress;
    } catch (e) {
      return _orCache(e, cache.progress, 'progress');
    }
  }

  /// Returns [fallback] when [error] is a connectivity / backend-unreachable
  /// failure and a last-known value exists; otherwise rethrows as
  /// [AppException] so the UI shows the real reason (session expired, …).
  static T _orCache<T>(Object error, T? fallback, String what) {
    final mapped = AppException.from(error);
    final recoverable = mapped.code == AppException.noInternet ||
        mapped.code == AppException.serverUnavailable;
    if (recoverable && fallback != null) {
      debugPrint('$what: using last known state after ${mapped.code}');
      return fallback;
    }
    throw mapped;
  }

  static CollectionProgress _parseProgress(dynamic data) {
    if (data is Map) {
      return CollectionProgress.fromJson(data.cast<String, dynamic>());
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      return CollectionProgress.fromJson(
        (data.first as Map).cast<String, dynamic>(),
      );
    }
    throw AppException.fromCode(AppException.serverUnavailable);
  }
}
