import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/models/capture_result.dart';
import '../../../core/models/encounter.dart';
import '../../../core/models/throw_quality.dart';

/// Where the capture mini-game is.
enum EncounterPhase {
  /// Waiting for the player to throw (ball draggable).
  idle,

  /// Ball in the air / professor being absorbed; backend call in flight.
  throwing,

  /// Ball on the ground shaking; waiting for animation + backend.
  shaking,

  /// Backend said captured (burst animation → `/result`).
  success,

  /// Backend said escaped (pop-out animation → `/result`).
  failed,

  /// Expired / not active / offline… (dialog → `/map`).
  error;

  bool get isResolved => this == success || this == failed || this == error;
}

/// Immutable state of one encounter screen.
class EncounterState {
  const EncounterState({
    required this.encounter,
    required this.remaining,
    this.phase = EncounterPhase.idle,
    this.quality,
    this.shakeCount = 2,
    this.result,
    this.error,
  });

  final Encounter encounter;
  final EncounterPhase phase;

  /// Time left before `expires_at` (never negative).
  final Duration remaining;

  /// The throw the player made (null while idle).
  final ThrowQuality? quality;

  /// How many times the ball shakes before the outcome (1..3).
  final int shakeCount;

  /// Backend result once available.
  final CaptureResult? result;

  /// Set together with [EncounterPhase.error].
  final AppException? error;

  bool get isExpired => remaining <= Duration.zero;
  bool get canThrow => phase == EncounterPhase.idle && !isExpired;

  /// `mm:ss` of [remaining] (rounded up to the next second).
  String get countdownLabel => formatCountdown(remaining);

  EncounterState copyWith({
    Encounter? encounter,
    EncounterPhase? phase,
    Duration? remaining,
    ThrowQuality? quality,
    int? shakeCount,
    CaptureResult? result,
    AppException? error,
  }) =>
      EncounterState(
        encounter: encounter ?? this.encounter,
        phase: phase ?? this.phase,
        remaining: remaining ?? this.remaining,
        quality: quality ?? this.quality,
        shakeCount: shakeCount ?? this.shakeCount,
        result: result ?? this.result,
        error: error ?? this.error,
      );

  @override
  String toString() =>
      'EncounterState(${encounter.id}, $phase, $countdownLabel, $quality)';
}

/// Formats a duration as `mm:ss`, rounding up so `2:59.4` shows `03:00`.
String formatCountdown(Duration d) {
  if (d <= Duration.zero) return '00:00';
  final totalSeconds = (d.inMilliseconds / 1000).ceil();
  final minutes = (totalSeconds ~/ 60).clamp(0, 99);
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// Orchestrates one encounter: countdown, throw phases and the
/// `resolve-capture` call. The backend call starts the moment the ball is
/// released; animations run in parallel and never block the result.
class EncounterController extends Notifier<EncounterState> {
  EncounterController(this.encounter, {Random? random, DateTime Function()? clock})
      : _random = random ?? Random(),
        _clock = clock ?? DateTime.now;

  final Encounter encounter;
  final Random _random;
  final DateTime Function() _clock;

  Timer? _ticker;
  Future<CaptureResult>? _pending;

  /// Last emitted state; safe to read even after the provider is disposed
  /// (the screen may still be finishing an animation).
  late EncounterState _snapshot;

  void _emit(EncounterState next) {
    _snapshot = next;
    if (ref.mounted) state = next;
  }

  /// Current state without throwing once disposed.
  EncounterState get current => ref.mounted ? state : _snapshot;

  @override
  EncounterState build() {
    ref.onDispose(_stopTicker);
    final remaining = encounter.remainingAt(_clock());
    if (remaining <= Duration.zero) {
      // Already expired when the screen opened: no countdown, straight to
      // the expiry dialog.
      return _snapshot = EncounterState(
        encounter: encounter,
        remaining: Duration.zero,
        phase: EncounterPhase.error,
        error: AppException.fromCode(AppException.encounterExpired),
      );
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    return _snapshot = EncounterState(encounter: encounter, remaining: remaining);
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (!ref.mounted) return;
    final remaining = encounter.remainingAt(_clock());
    if (remaining <= Duration.zero) {
      _stopTicker();
      if (state.phase == EncounterPhase.idle) {
        _emit(
          state.copyWith(
            remaining: Duration.zero,
            phase: EncounterPhase.error,
            error: AppException.fromCode(AppException.encounterExpired),
          ),
        );
        return;
      }
    }
    _emit(state.copyWith(remaining: remaining));
  }

  /// Player released the ball. Starts the backend call immediately and moves
  /// to [EncounterPhase.throwing]. Ignored (returns `false`) when a throw is
  /// already in progress or the encounter is over (double-submission guard).
  bool throwBall(ThrowQuality quality) {
    if (!ref.mounted || !state.canThrow) return false;
    _emit(
      state.copyWith(
        phase: EncounterPhase.throwing,
        quality: quality,
        shakeCount: 1 + _random.nextInt(3),
      ),
    );
    _pending = _resolve(quality);
    return true;
  }

  /// The ball landed: switch to the shaking phase (visual only).
  void startShaking() {
    if (current.phase == EncounterPhase.throwing) {
      _emit(current.copyWith(phase: EncounterPhase.shaking));
    }
  }

  /// Called by the screen once its throw animation is done (or failed).
  /// Waits for the backend and moves to `success` / `failed` / `error`.
  /// Returns the final state (also after the provider was disposed).
  Future<EncounterState> completeThrow() async {
    final pending = _pending;
    if (pending == null) return current;
    final resolved = await pending;
    // Settle the phase only once, even if the screen calls twice.
    if (current.phase.isResolved) return current;
    _emit(
      current.copyWith(
        phase: resolved.success ? EncounterPhase.success : EncounterPhase.failed,
        result: resolved,
      ),
    );
    return current;
  }

  Future<CaptureResult> _resolve(ThrowQuality quality) async {
    final service = ref.read(captureServiceProvider);
    try {
      return await service.resolveCapture(
        encounterId: encounter.id,
        quality: quality,
      );
    } catch (e, st) {
      final error = AppException.from(e);
      debugPrint('resolveCapture failed: $error\n$st');
      if (!current.phase.isResolved) {
        _emit(current.copyWith(phase: EncounterPhase.error, error: error));
      }
      // Never rethrow: the caller reads the error from the state.
      return const CaptureResult.failed();
    }
  }
}

/// One controller per encounter (== by id). Auto-disposed with the screen.
final encounterControllerProvider = NotifierProvider.autoDispose
    .family<EncounterController, EncounterState, Encounter>(
  EncounterController.new,
);
