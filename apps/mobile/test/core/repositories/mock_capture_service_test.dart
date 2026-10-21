import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/mock/demo_game_state.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/repositories/mock_capture_service.dart';
import 'package:profesor_go/core/repositories/mock_professor_repository.dart';

/// Deterministic Random: every roll returns [value].
class FixedRandom implements Random {
  FixedRandom(this.value);
  final double value;

  @override
  bool nextBool() => value < 0.5;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => (value * max).floor().clamp(0, max - 1);
}

Matcher throwsAppCode(String code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

void main() {
  late DateTime now;
  late DemoGameState state;
  late MockCaptureService service;

  MockCaptureService build({double roll = 0.0}) => MockCaptureService(
    state,
    random: FixedRandom(roll),
    delay: Duration.zero,
  );

  setUp(() {
    now = DateTime.utc(2026, 9, 16, 10);
    state = DemoGameState(clock: () => now);
    service = build();
  });

  group('startEncounter', () {
    test('returns an encounter for a valid demo tag', () async {
      final e = await service.startEncounter('DEMO-TAG-01');
      expect(e.professor.id, demoProfessors.first.id);
      expect(e.professor.displayName, 'Prof. Henry');
      expect(e.status, EncounterStatus.active);
      expect(e.expiresAt, now.add(const Duration(seconds: 180)));
      expect(service.cachedEncounter(e.id), e);
      expect(service.lastEncounter, e);
    });

    test('is tolerant of tag case / whitespace', () async {
      final e = await service.startEncounter(' demo-tag-08 ');
      expect(e.professor.rarity, Rarity.legendary);
    });

    test('rejects unknown, disabled and unassigned tags', () async {
      await expectLater(
        service.startEncounter('NOPE-99'),
        throwsAppCode(AppException.tagNotFound),
      );
      await expectLater(
        service.startEncounter(''),
        throwsAppCode(AppException.invalidInput),
      );

      state = DemoGameState(
        clock: () => now,
        tags: [
          DemoTagSeed(
            identifier: 'OFF-01',
            professorId: demoProfessors.first.id,
            active: false,
          ),
          const DemoTagSeed(identifier: 'ORPHAN-01', professorId: null),
        ],
      );
      service = build();
      await expectLater(
        service.startEncounter('OFF-01'),
        throwsAppCode(AppException.tagDisabled),
      );
      await expectLater(
        service.startEncounter('ORPHAN-01'),
        throwsAppCode(AppException.tagNotFound),
      );
    });

    test('rejects tags of inactive professors', () async {
      state = DemoGameState(
        clock: () => now,
        professors: [demoProfessors.first.copyWith(active: false)],
      );
      service = build();
      await expectLater(
        service.startEncounter('DEMO-TAG-01'),
        throwsAppCode(AppException.professorDisabled),
      );
    });

    test('expires previous ACTIVE encounters of the same professor', () async {
      final first = await service.startEncounter('DEMO-TAG-02');
      final second = await service.startEncounter('DEMO-TAG-02');
      expect(state.encounterById(first.id)!.status, EncounterStatus.expired);
      expect(state.encounterById(second.id)!.status, EncounterStatus.active);
      await expectLater(
        service.resolveCapture(
          encounterId: first.id,
          quality: ThrowQuality.good,
        ),
        throwsAppCode(AppException.encounterNotActive),
      );
    });
  });

  group('resolveCapture', () {
    test('MISS always fails, even with a perfect roll', () async {
      final e = await service.startEncounter('DEMO-TAG-01');
      final result = await service.resolveCapture(
        encounterId: e.id,
        quality: ThrowQuality.miss,
      );
      expect(result.success, isFalse);
      expect(result.retryRequiresNewNfcScan, isTrue);
      expect(result.collection, isNull);
      expect(state.encounterById(e.id)!.status, EncounterStatus.failed);
      expect(state.isCaptured(demoProfessors.first.id), isFalse);
      // A failed encounter cannot be retried without a new scan.
      await expectLater(
        service.resolveCapture(encounterId: e.id, quality: ThrowQuality.good),
        throwsAppCode(AppException.encounterNotActive),
      );
    });

    test('succeeds with roll 0.0 and stores the capture once', () async {
      final e = await service.startEncounter('DEMO-TAG-04');
      final result = await service.resolveCapture(
        encounterId: e.id,
        quality: ThrowQuality.great,
      );
      expect(result.success, isTrue);
      expect(result.professorId, demoProfessors[3].id);
      expect(
        result.collection,
        const CollectionProgress(captured: 1, total: 10, completed: false),
      );
      expect(state.captures.single.throwQuality, ThrowQuality.great);
      expect(state.captures.single.encounterId, e.id);
      expect(service.cachedEncounter(e.id)!.status, EncounterStatus.success);

      // Idempotent: resolving the same successful encounter again returns success.
      final again = await service.resolveCapture(
        encounterId: e.id,
        quality: ThrowQuality.miss,
      );
      expect(again.success, isTrue);
      expect(state.captures.length, 1);
    });

    test('fails when roll >= probability', () async {
      service = build(roll: 0.95); // legendary base 0.25 + 0.20 = 0.45
      final e = await service.startEncounter('DEMO-TAG-08');
      final result = await service.resolveCapture(
        encounterId: e.id,
        quality: ThrowQuality.excellent,
      );
      expect(result.success, isFalse);

      service = build(roll: 0.44);
      final e2 = await service.startEncounter('DEMO-TAG-08');
      final ok = await service.resolveCapture(
        encounterId: e2.id,
        quality: ThrowQuality.excellent,
      );
      expect(ok.success, isTrue);
    });

    test('already captured professor cannot be encountered again', () async {
      final e = await service.startEncounter('DEMO-TAG-03');
      await service.resolveCapture(
        encounterId: e.id,
        quality: ThrowQuality.good,
      );
      await expectLater(
        service.startEncounter('DEMO-TAG-03'),
        throwsAppCode(AppException.alreadyCaptured),
      );
    });

    test('expired encounter throws ENCOUNTER_EXPIRED and marks it', () async {
      final e = await service.startEncounter('DEMO-TAG-05');
      now = now.add(const Duration(seconds: 181));
      await expectLater(
        service.resolveCapture(encounterId: e.id, quality: ThrowQuality.good),
        throwsAppCode(AppException.encounterExpired),
      );
      expect(state.encounterById(e.id)!.status, EncounterStatus.expired);
      expect(service.cachedEncounter(e.id)!.status, EncounterStatus.expired);
    });

    test('unknown encounter throws ENCOUNTER_NOT_FOUND', () async {
      await expectLater(
        service.resolveCapture(
          encounterId: 'ghost',
          quality: ThrowQuality.good,
        ),
        throwsAppCode(AppException.encounterNotFound),
      );
    });

    test('completing the collection sets completed + timestamp', () async {
      for (var n = 1; n <= 10; n++) {
        final e = await service.startEncounter(
          'DEMO-TAG-${n.toString().padLeft(2, '0')}',
        );
        final r = await service.resolveCapture(
          encounterId: e.id,
          quality: ThrowQuality.good,
        );
        expect(r.success, isTrue);
        expect(r.collection!.completed, n == 10);
      }
      expect(state.collectionCompletedAt, now);

      final repo = MockProfessorRepository(state, delay: Duration.zero);
      final progress = await repo.getProgress();
      expect(
        progress,
        const CollectionProgress(captured: 10, total: 10, completed: true),
      );
      expect((await repo.getMyCaptures()).length, 10);
      final professors = await repo.getActiveProfessors();
      expect(professors.length, 10);
      expect(professors.first.rarity, Rarity.legendary); // sorted by rarity
      expect(repo.cache.progress, progress);
    });
  });

  test('captureProbability matches the server formula', () {
    expect(
      MockCaptureService.captureProbability(0.80, ThrowQuality.excellent),
      1.0,
    );
    expect(MockCaptureService.captureProbability(0.25, ThrowQuality.miss), 0.0);
    expect(
      MockCaptureService.captureProbability(0.40, ThrowQuality.great),
      closeTo(0.5, 1e-9),
    );
    expect(
      MockCaptureService.captureProbability(0.60, ThrowQuality.good),
      0.60,
    );
  });
}
