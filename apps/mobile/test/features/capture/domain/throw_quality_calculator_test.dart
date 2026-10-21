import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/models/throw_quality.dart';
import 'package:profesor_go/features/capture/domain/throw_quality_calculator.dart';

void main() {
  const start = Offset(200, 600);
  const target = Offset(200, 100);

  group('flick throw', () {
    const screen = Size(400, 800);

    test('a short upward flick launches toward the professor', () {
      final evaluation = evaluateFlickThrow(
        start: const Offset(200, 690),
        end: const Offset(200, 570),
        targetCenter: target,
        duration: const Duration(milliseconds: 180),
        screenSize: screen,
      );
      expect(evaluation.quality, ThrowQuality.excellent);
      expect(evaluation.impact, target);
      expect(evaluation.metrics.distance, 120);
    });

    test(
      'diagonal aim changes quality without requiring a full-screen drag',
      () {
        final evaluation = evaluateFlickThrow(
          start: const Offset(200, 690),
          end: const Offset(245, 510),
          targetCenter: target,
          duration: const Duration(milliseconds: 180),
          screenSize: screen,
          targetRadius: 20,
        );
        expect(evaluation.impact.dx, closeTo(312.5, 0.01));
        expect(evaluation.quality, ThrowQuality.miss);
      },
    );

    test('tap, downward and sideways gestures never capture', () {
      for (final end in <Offset>[
        const Offset(200, 685),
        const Offset(200, 740),
        const Offset(330, 680),
      ]) {
        expect(
          evaluateFlickThrow(
            start: const Offset(200, 690),
            end: end,
            targetCenter: target,
            duration: const Duration(milliseconds: 200),
            screenSize: screen,
          ).quality,
          ThrowQuality.miss,
        );
      }
    });
  });

  /// Upward swipe from [start] releasing [error] px away from [target].
  ThrowQuality qualityAt(
    double error, {
    double radius = 0,
    ThrowThresholds? t,
  }) => calculateThrowQuality(
    start: start,
    end: target + Offset(error, 0),
    targetCenter: target,
    targetRadius: radius,
    thresholds: t ?? const ThrowThresholds(),
  );

  group('calculateThrowQuality bands', () {
    test('dead center is EXCELLENT', () {
      expect(qualityAt(0), ThrowQuality.excellent);
    });

    test('inside each band', () {
      expect(qualityAt(10), ThrowQuality.excellent);
      expect(qualityAt(35), ThrowQuality.great);
      expect(qualityAt(70), ThrowQuality.good);
      expect(qualityAt(200), ThrowQuality.miss);
    });

    test('boundaries are inclusive', () {
      expect(qualityAt(20), ThrowQuality.excellent);
      expect(qualityAt(20.001), ThrowQuality.great);
      expect(qualityAt(50), ThrowQuality.great);
      expect(qualityAt(50.001), ThrowQuality.good);
      expect(qualityAt(90), ThrowQuality.good);
      expect(qualityAt(90.001), ThrowQuality.miss);
    });

    test('targetRadius forgives the sprite size', () {
      // error = accuracy - radius
      expect(qualityAt(60, radius: 40), ThrowQuality.excellent); // 20
      expect(qualityAt(61, radius: 40), ThrowQuality.great); // 21
      expect(qualityAt(90, radius: 40), ThrowQuality.great); // 50
      expect(qualityAt(130, radius: 40), ThrowQuality.good); // 90
      expect(qualityAt(131, radius: 40), ThrowQuality.miss); // 91
      // A negative radius is treated as 0.
      expect(qualityAt(90, radius: -5), ThrowQuality.good);
      expect(qualityAt(91, radius: -5), ThrowQuality.miss);
    });

    test('custom thresholds', () {
      const wide = ThrowThresholds(excellent: 40, great: 100, good: 180);
      expect(qualityAt(35, t: wide), ThrowQuality.excellent);
      expect(qualityAt(150, t: wide), ThrowQuality.good);
      expect(qualityAt(181, t: wide), ThrowQuality.miss);
    });

    test('diagonal error uses euclidean distance', () {
      final q = calculateThrowQuality(
        start: start,
        end: target + const Offset(30, 40), // 50 px away
        targetCenter: target,
      );
      expect(q, ThrowQuality.great);
    });
  });

  group('MISS rules', () {
    test('downward swipe is a MISS even when it ends on the target', () {
      final q = calculateThrowQuality(
        start: const Offset(200, 50),
        end: target,
        targetCenter: target,
      );
      expect(q, ThrowQuality.miss);
    });

    test('short swipe (< 40 px) is a MISS even when it ends on the target', () {
      final q = calculateThrowQuality(
        start: target + const Offset(0, 39),
        end: target,
        targetCenter: target,
      );
      expect(q, ThrowQuality.miss);
      // Exactly 40 px counts as a throw.
      final ok = calculateThrowQuality(
        start: target + const Offset(0, 40),
        end: target,
        targetCenter: target,
      );
      expect(ok, ThrowQuality.excellent);
    });

    test('zero-length swipe is a MISS', () {
      expect(
        calculateThrowQuality(start: target, end: target, targetCenter: target),
        ThrowQuality.miss,
      );
    });

    test('horizontal swipe is not downward; quality by accuracy', () {
      final q = calculateThrowQuality(
        start: const Offset(100, 100),
        end: target,
        targetCenter: target,
      );
      expect(q, ThrowQuality.excellent);
    });
  });

  group('normalization', () {
    test('factor is min(w, h) / 400', () {
      expect(ThrowThresholds.normalizationFactor(const Size(400, 800)), 1);
      expect(ThrowThresholds.normalizationFactor(const Size(800, 600)), 1.5);
      expect(ThrowThresholds.normalizationFactor(const Size(600, 200)), 0.5);
      expect(ThrowThresholds.normalizationFactor(Size.zero), 1);
      expect(
        ThrowThresholds.normalizationFactor(const Size(double.infinity, 10)),
        0.025,
      );
    });

    test('scaled thresholds', () {
      const t = ThrowThresholds();
      expect(
        t.normalizedFor(const Size(800, 600)),
        const ThrowThresholds(excellent: 30, great: 75, good: 135),
      );
      expect(
        t.scaled(0.5),
        const ThrowThresholds(excellent: 10, great: 25, good: 45),
      );
    });

    test('calculateThrowQualityNormalized widens the bands on big screens', () {
      ThrowQuality at(double error, Size screen) =>
          calculateThrowQualityNormalized(
            start: start,
            end: target + Offset(error, 0),
            targetCenter: target,
            screenSize: screen,
          );
      const big = Size(800, 600); // ×1.5 → 30 / 75 / 135
      expect(at(25, big), ThrowQuality.excellent);
      expect(at(30, big), ThrowQuality.excellent);
      expect(at(31, big), ThrowQuality.great);
      expect(at(75, big), ThrowQuality.great);
      expect(at(120, big), ThrowQuality.good);
      expect(at(136, big), ThrowQuality.miss);

      const small = Size(200, 600); // ×0.5 → 10 / 25 / 45
      expect(at(10, small), ThrowQuality.excellent);
      expect(at(11, small), ThrowQuality.great);
      expect(at(45, small), ThrowQuality.good);
      expect(at(46, small), ThrowQuality.miss);
    });

    test('evaluateThrow with screenSize matches the normalized variant', () {
      final e = evaluateThrow(
        start: start,
        end: target + const Offset(0, 28),
        targetCenter: target,
        duration: const Duration(milliseconds: 200),
        screenSize: const Size(800, 600),
      );
      expect(e.quality, ThrowQuality.excellent);
      expect(e.metrics.accuracy, 28);
    });
  });

  group('ThrowMetrics', () {
    test('velocity, direction, distance and accuracy of an upward swipe', () {
      final m = ThrowMetrics.fromSwipe(
        start: start,
        end: const Offset(200, 100),
        duration: const Duration(milliseconds: 250),
        targetCenter: const Offset(230, 60),
      );
      expect(m.distance, 500);
      expect(m.velocity, 2); // 500 px / 250 ms
      expect(m.direction, closeTo(-math.pi / 2, 1e-9));
      expect(m.accuracy, 50); // 30-40-50 triangle
      expect(m.isDownward, isFalse);
      expect(m.isNegligible, isFalse);
    });

    test('direction of a rightward and a downward swipe', () {
      final right = ThrowMetrics.fromSwipe(
        start: Offset.zero,
        end: const Offset(100, 0),
        duration: const Duration(milliseconds: 100),
        targetCenter: Offset.zero,
      );
      expect(right.direction, 0);
      final down = ThrowMetrics.fromSwipe(
        start: Offset.zero,
        end: const Offset(0, 100),
        duration: const Duration(milliseconds: 100),
        targetCenter: Offset.zero,
      );
      expect(down.direction, closeTo(math.pi / 2, 1e-9));
      expect(down.isDownward, isTrue);
    });

    test('zero duration does not produce infinity', () {
      final m = ThrowMetrics.fromSwipe(
        start: Offset.zero,
        end: const Offset(0, -80),
        duration: Duration.zero,
        targetCenter: Offset.zero,
      );
      expect(m.velocity.isFinite, isTrue);
      expect(m.velocity, 80);
    });

    test('short swipe is negligible', () {
      final m = ThrowMetrics.fromSwipe(
        start: Offset.zero,
        end: const Offset(0, -39.9),
        duration: const Duration(milliseconds: 100),
        targetCenter: Offset.zero,
      );
      expect(m.isNegligible, isTrue);
      expect(qualityFromMetrics(m), ThrowQuality.miss);
    });
  });
}
