import 'dart:math';

import '../errors/app_exception.dart';
import '../mock/demo_game_state.dart';
import '../models/capture.dart';
import '../models/capture_result.dart';
import '../models/encounter.dart';
import '../models/throw_quality.dart';
import 'capture_service.dart';

/// In-memory [CaptureService] that behaves like the Edge Functions +
/// `resolve_capture_tx` (CONTRACTS §4/§9):
///
/// * `startEncounter` validates tag → professor → not already captured,
///   expires previous ACTIVE encounters and creates one valid for
///   `encounterExpirationSeconds` (180 by default).
/// * `resolveCapture` computes `p = clamp(base + bonus, 0, 1)` and succeeds
///   when `roll < p`. `MISS` has bonus `-1.0`, so it always fails.
class MockCaptureService extends CaptureService {
  MockCaptureService(
    this.state, {
    Random? random,
    this.delay = const Duration(milliseconds: 250),
  }) : _random = random ?? Random();

  final DemoGameState state;
  final Duration delay;
  final Random _random;

  Future<void> _simulateLatency() async {
    await state.ensureLoaded();
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<Encounter> startQrEncounter(String qrCode) async {
    throw AppException.fromCode(AppException.tagNotFound);
  }

  @override
  Future<Encounter> startEncounter(String tagIdentifier) async {
    await _simulateLatency();
    final id = tagIdentifier.trim();
    if (id.isEmpty) throw AppException.fromCode(AppException.invalidInput);

    final tag = state.tagByIdentifier(id);
    if (tag == null) throw AppException.fromCode(AppException.tagNotFound);
    if (!tag.active) throw AppException.fromCode(AppException.tagDisabled);

    final professor = state.professorById(tag.professorId);
    if (professor == null) {
      throw AppException.fromCode(AppException.tagNotFound);
    }
    if (!professor.active) {
      throw AppException.fromCode(AppException.professorDisabled);
    }
    if (state.isCaptured(professor.id)) {
      throw AppException.fromCode(AppException.alreadyCaptured);
    }

    final now = state.now();
    final encounter = Encounter(
      id: state.nextId('enc'),
      expiresAt: now.add(Duration(seconds: state.encounterExpirationSeconds)),
      professor: professor.summary,
      createdAt: now,
    );
    state.putEncounter(encounter);
    rememberEncounter(encounter);
    return encounter;
  }

  @override
  Future<CaptureResult> resolveCapture({
    required String encounterId,
    required ThrowQuality quality,
  }) async {
    await _simulateLatency();
    final encounter = state.encounterById(encounterId);
    if (encounter == null) {
      throw AppException.fromCode(AppException.encounterNotFound);
    }
    final professorId = encounter.professor.id;

    // Idempotent: already resolved successfully with an existing capture.
    if (encounter.status == EncounterStatus.success &&
        state.isCaptured(professorId)) {
      return CaptureResult(
        success: true,
        professorId: professorId,
        collection: state.progress(),
        retryRequiresNewNfcScan: false,
      );
    }
    if (encounter.status != EncounterStatus.active) {
      throw AppException.fromCode(AppException.encounterNotActive);
    }
    if (encounter.isExpiredAt(state.now())) {
      _setStatus(encounter, EncounterStatus.expired);
      throw AppException.fromCode(AppException.encounterExpired);
    }
    if (state.isCaptured(professorId)) {
      _setStatus(encounter, EncounterStatus.expired);
      throw AppException.fromCode(AppException.alreadyCaptured);
    }

    final professor = state.professorById(professorId);
    final baseRate =
        professor?.baseCaptureRate ??
        encounter.professor.rarity.defaultCaptureRate;
    final probability = captureProbability(baseRate, quality);
    final roll = _random.nextDouble();

    if (roll < probability) {
      _setStatus(encounter, EncounterStatus.success);
      final progress = await state.addCapture(
        Capture(
          id: state.nextId('cap'),
          userId: state.userId,
          professorId: professorId,
          encounterId: encounter.id,
          throwQuality: quality,
          capturedAt: state.now(),
        ),
      );
      return CaptureResult(
        success: true,
        professorId: professorId,
        collection: progress,
        retryRequiresNewNfcScan: false,
      );
    }
    _setStatus(encounter, EncounterStatus.failed);
    return const CaptureResult.failed();
  }

  void _setStatus(Encounter encounter, EncounterStatus status) {
    state.setEncounterStatus(encounter.id, status);
    updateCachedEncounter(encounter.copyWith(status: status));
  }

  /// `p = clamp(base_capture_rate + throw_bonus[quality], 0, 1)`.
  static double captureProbability(double baseRate, ThrowQuality quality) =>
      (baseRate + quality.bonus).clamp(0.0, 1.0);
}
