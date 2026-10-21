import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/repositories/capture_service.dart';
import 'package:profesor_go/features/capture/presentation/encounter_controller.dart';

import '../fakes.dart';

void main() {
  group('formatCountdown', () {
    test('mm:ss rounded up', () {
      expect(formatCountdown(const Duration(minutes: 3)), '03:00');
      expect(formatCountdown(const Duration(minutes: 2, seconds: 59, milliseconds: 400)), '03:00');
      expect(formatCountdown(const Duration(seconds: 59)), '00:59');
      expect(formatCountdown(const Duration(milliseconds: 10)), '00:01');
      expect(formatCountdown(Duration.zero), '00:00');
      expect(formatCountdown(const Duration(seconds: -5)), '00:00');
    });
  });

  group('EncounterController', () {
    late DateTime now;
    late FakeCaptureService service;
    late ProviderContainer container;

    setUp(() {
      now = DateTime.utc(2026, 9, 16, 10);
      service = FakeCaptureService();
      container = ProviderContainer(
        overrides: [
          captureServiceProvider.overrideWithValue(service as CaptureService),
          encounterControllerProvider.overrideWith2(
            (encounter) => EncounterController(encounter, clock: () => now),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    testWidgets('counts down every second and expires', (tester) async {
      final encounter = makeEncounter(now: now, ttl: const Duration(seconds: 3));
      final provider = encounterControllerProvider(encounter);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);

      expect(container.read(provider).countdownLabel, '00:03');
      expect(container.read(provider).canThrow, isTrue);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(provider).countdownLabel, '00:02');

      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      final state = container.read(provider);
      expect(state.countdownLabel, '00:00');
      expect(state.isExpired, isTrue);
      expect(state.phase, EncounterPhase.error);
      expect(state.error?.code, AppException.encounterExpired);
      expect(state.canThrow, isFalse);
      expect(container.read(provider.notifier).throwBall(ThrowQuality.good), isFalse);
    });

    test('starts in the error phase when already expired', () {
      final encounter = makeEncounter(now: now, ttl: const Duration(seconds: -1));
      final state = container.read(encounterControllerProvider(encounter));
      expect(state.phase, EncounterPhase.error);
      expect(state.error?.code, AppException.encounterExpired);
    });

    test('throwBall calls the backend immediately and completeThrow settles success', () async {
      service.result = const CaptureResult(
        success: true,
        professorId: 'p',
        collection: CollectionProgress(captured: 1, total: 8, completed: false),
      );
      final encounter = makeEncounter(now: now);
      final provider = encounterControllerProvider(encounter);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(provider.notifier);

      expect(notifier.throwBall(ThrowQuality.great), isTrue);
      expect(container.read(provider).phase, EncounterPhase.throwing);
      expect(container.read(provider).quality, ThrowQuality.great);
      expect(container.read(provider).shakeCount, inInclusiveRange(1, 3));
      // Backend already called, before any animation callback.
      expect(service.resolved.single.quality, ThrowQuality.great);
      expect(service.resolved.single.encounterId, 'enc-1');

      // Double submission is ignored.
      expect(notifier.throwBall(ThrowQuality.excellent), isFalse);
      expect(service.resolved.length, 1);

      notifier.startShaking();
      expect(container.read(provider).phase, EncounterPhase.shaking);

      final state = await notifier.completeThrow();
      expect(state.phase, EncounterPhase.success);
      expect(state.result?.collection?.captured, 1);
      // Idempotent.
      expect((await notifier.completeThrow()).phase, EncounterPhase.success);
    });

    test('completeThrow settles failed', () async {
      final encounter = makeEncounter(now: now);
      final provider = encounterControllerProvider(encounter);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(provider.notifier);
      notifier.throwBall(ThrowQuality.miss);
      final state = await notifier.completeThrow();
      expect(state.phase, EncounterPhase.failed);
      expect(state.result?.success, isFalse);
    });

    test('backend error becomes the error phase, never throws', () async {
      service.resolveError = AppException.fromCode(AppException.encounterNotActive);
      final encounter = makeEncounter(now: now);
      final provider = encounterControllerProvider(encounter);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(provider.notifier);
      notifier.throwBall(ThrowQuality.good);
      final state = await notifier.completeThrow();
      expect(state.phase, EncounterPhase.error);
      expect(state.error?.code, AppException.encounterNotActive);
    });

    test('completeThrow without a throw is a no-op', () async {
      final encounter = makeEncounter(now: now);
      final provider = encounterControllerProvider(encounter);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final state = await container.read(provider.notifier).completeThrow();
      expect(state.phase, EncounterPhase.idle);
      expect(service.resolved, isEmpty);
    });
  });
}
