import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';
import '../models/capture_result.dart';
import '../models/encounter.dart';
import '../models/throw_quality.dart';
import 'capture_service.dart';

/// [CaptureService] calling the `start-encounter` / `resolve-capture`
/// Edge Functions (CONTRACTS §4). The user JWT is attached automatically by
/// the Supabase client.
///
/// Verified against the live backend:
/// * `start-encounter` 200 → `{"encounter_id": uuid,
///   "expires_at": "2026-09-17T05:15:31.369Z" (ISO-8601, ms, UTC),
///   "professor": {id, display_name, rarity (upper-case),
///   sprite_url|null, description|null}}`.
/// * `resolve-capture` 200 success → `{"success": true, "professor_id": uuid,
///   "collection": {"total": 8, "captured": 1, "completed": false}}`;
///   failure → `{"success": false, "retry_requires_new_nfc_scan": true}`.
/// * errors → HTTP 400/401/403/404/409/410 with
///   `{"error": "<CODE>", "message": "<texto>"}`, which
///   `AppException.from` turns into the matching code.
///
/// No probability is ever computed here: the outcome is whatever the server
/// says (CONTRACTS §9/§10).
class SupabaseCaptureService extends CaptureService {
  SupabaseCaptureService(
    this._client, {
    this.timeout = const Duration(seconds: 15),
  });

  final SupabaseClient _client;
  final Duration timeout;

  @override
  Future<Encounter> startEncounter(String tagIdentifier) async {
    final id = tagIdentifier.trim();
    if (id.isEmpty) throw AppException.fromCode(AppException.invalidInput);
    return _start({'tag_identifier': id});
  }

  @override
  Future<Encounter> startQrEncounter(String qrCode) async {
    final code = qrCode.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(code)) {
      throw AppException.fromCode(AppException.invalidInput);
    }
    return _start({'qr_code': code});
  }

  Future<Encounter> _start(Map<String, dynamic> credential) async {
    final data = await _invoke('start-encounter', credential);
    final encounter = _parse(data, Encounter.fromJson);
    rememberEncounter(encounter);
    return encounter;
  }

  @override
  Future<CaptureResult> resolveCapture({
    required String encounterId,
    required ThrowQuality quality,
  }) async {
    final id = encounterId.trim();
    if (id.isEmpty) throw AppException.fromCode(AppException.invalidInput);
    final data = await _invoke('resolve-capture', {
      'encounter_id': id,
      'throw_quality': quality.wireValue,
    });
    final result = _parse(data, CaptureResult.fromJson);
    final cached = cachedEncounter(id);
    if (cached != null) {
      updateCachedEncounter(
        cached.copyWith(
          status: result.success
              ? EncounterStatus.success
              : EncounterStatus.failed,
        ),
      );
    }
    return result;
  }

  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.functions
          .invoke(name, body: body)
          .timeout(timeout);
      final data = response.data;
      if (data is Map) return data.cast<String, dynamic>();
      throw AppException.fromCode(AppException.serverUnavailable);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Decodes a 200 body, turning any shape surprise into a friendly
  /// `SERVER_UNAVAILABLE` instead of a raw `TypeError` / `FormatException`.
  static T _parse<T>(
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) decode,
  ) {
    try {
      return decode(data);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException.fromCode(AppException.serverUnavailable, cause: e);
    }
  }
}
