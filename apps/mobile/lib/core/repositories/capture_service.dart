import 'package:flutter/foundation.dart';

import '../models/capture_result.dart';
import '../models/encounter.dart';
import '../models/throw_quality.dart';

/// The capture flow: NFC tag → encounter → throw → result.
/// Errors are thrown as `AppException` (codes in CONTRACTS §4).
abstract class CaptureService {
  final Map<String, Encounter> _recent = {};
  Encounter? _last;

  /// `start-encounter`. Throws `TAG_NOT_FOUND`, `TAG_DISABLED`,
  /// `PROFESSOR_DISABLED`, `ALREADY_CAPTURED`, `NO_INTERNET`, ...
  Future<Encounter> startEncounter(String tagIdentifier);

  /// `resolve-capture`. Throws `ENCOUNTER_EXPIRED`, `ENCOUNTER_NOT_ACTIVE`,
  /// `ALREADY_CAPTURED`, ...
  Future<CaptureResult> resolveCapture({
    required String encounterId,
    required ThrowQuality quality,
  });

  /// Encounters started in this session, so a screen that only has the
  /// `:encounterId` route parameter can recover the professor + expiry.
  Encounter? cachedEncounter(String encounterId) => _recent[encounterId];

  /// The most recently started encounter (null before the first scan).
  Encounter? get lastEncounter => _last;

  @protected
  void rememberEncounter(Encounter encounter) {
    _recent[encounter.id] = encounter;
    _last = encounter;
  }

  @protected
  void updateCachedEncounter(Encounter encounter) {
    if (_recent.containsKey(encounter.id)) _recent[encounter.id] = encounter;
    if (_last?.id == encounter.id) _last = encounter;
  }
}
