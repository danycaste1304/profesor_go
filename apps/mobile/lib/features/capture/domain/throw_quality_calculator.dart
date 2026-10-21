import 'dart:math' as math;
import 'dart:ui';

import '../../../core/models/throw_quality.dart';

/// Reference screen size (shortest side, logical px) the default thresholds
/// were tuned for. Larger screens get proportionally larger thresholds.
const double kThrowReferenceSize = 400;

/// Swipes shorter than this (logical px) are not a real throw → MISS.
const double kMinSwipeDistance = 40;

/// Accuracy bands (distance from the release point to the target center,
/// in logical px). Inclusive: `accuracy <= excellent` → EXCELLENT, etc.
class ThrowThresholds {
  const ThrowThresholds({this.excellent = 20, this.great = 50, this.good = 90})
    : assert(excellent >= 0),
      assert(great >= excellent),
      assert(good >= great);

  final double excellent;
  final double great;
  final double good;

  /// Thresholds multiplied by [factor] (used for screen-size normalization).
  ThrowThresholds scaled(double factor) => ThrowThresholds(
    excellent: excellent * factor,
    great: great * factor,
    good: good * factor,
  );

  /// `min(width, height) / 400`; `1` for degenerate sizes.
  static double normalizationFactor(Size screenSize) {
    final shortest = math.min(screenSize.width, screenSize.height);
    if (!shortest.isFinite || shortest <= 0) return 1;
    return shortest / kThrowReferenceSize;
  }

  /// Thresholds scaled for [screenSize].
  ThrowThresholds normalizedFor(Size screenSize) =>
      scaled(normalizationFactor(screenSize));

  @override
  bool operator ==(Object other) =>
      other is ThrowThresholds &&
      other.excellent == excellent &&
      other.great == great &&
      other.good == good;

  @override
  int get hashCode => Object.hash(excellent, great, good);

  @override
  String toString() =>
      'ThrowThresholds(excellent: $excellent, great: $great, good: $good)';
}

/// Measurements of one swipe (screen coordinates: +y points down).
class ThrowMetrics {
  const ThrowMetrics({
    required this.velocity,
    required this.direction,
    required this.distance,
    required this.accuracy,
    required this.delta,
  });

  /// Computes the metrics of a swipe from [start] to [end] that took
  /// [duration], aimed at [targetCenter].
  factory ThrowMetrics.fromSwipe({
    required Offset start,
    required Offset end,
    required Duration duration,
    required Offset targetCenter,
  }) {
    final delta = end - start;
    final distance = delta.distance;
    // Avoid infinity on a zero-length duration (tests, synthetic gestures).
    final millis = math.max(1, duration.inMilliseconds);
    return ThrowMetrics(
      velocity: distance / millis,
      direction: distance == 0 ? 0 : math.atan2(delta.dy, delta.dx),
      distance: distance,
      accuracy: (end - targetCenter).distance,
      delta: delta,
    );
  }

  /// Logical px per millisecond.
  final double velocity;

  /// Angle of the swipe in radians (`atan2(dy, dx)`); straight up is `-π/2`.
  final double direction;

  /// Length of the swipe in logical px.
  final double distance;

  /// Distance from the release point to the target center (logical px).
  final double accuracy;

  /// `end - start`.
  final Offset delta;

  /// The swipe moved towards the bottom of the screen.
  bool get isDownward => delta.dy > 0;

  /// The swipe is too short to count as a throw.
  bool get isNegligible => distance < kMinSwipeDistance;

  @override
  String toString() =>
      'ThrowMetrics(v=${velocity.toStringAsFixed(2)}px/ms, '
      'dir=${direction.toStringAsFixed(2)}rad, d=${distance.toStringAsFixed(1)}, '
      'acc=${accuracy.toStringAsFixed(1)})';
}

/// Metrics + resulting quality of one throw.
typedef ThrowEvaluation = ({ThrowMetrics metrics, ThrowQuality quality});

/// A flick begins at the launch pad and travels toward the professor. Its
/// projected horizontal crossing at the professor's height determines aim;
/// the player does not need to drag a finger all the way across the screen.
typedef FlickThrowEvaluation = ({
  ThrowMetrics metrics,
  ThrowQuality quality,
  Offset impact,
});

FlickThrowEvaluation evaluateFlickThrow({
  required Offset start,
  required Offset end,
  required Offset targetCenter,
  required Duration duration,
  required Size screenSize,
  double targetRadius = 0,
  ThrowThresholds thresholds = const ThrowThresholds(),
}) {
  final delta = end - start;
  final upward = -delta.dy;
  // A short flick still reaches the far target. Capping extrapolation keeps
  // small horizontal finger jitter from turning a good throw into a MISS.
  final projection = upward <= 0
      ? 1.0
      : ((start.dy - targetCenter.dy) / upward).clamp(1.0, 2.5);
  final impact = Offset(start.dx + delta.dx * projection, targetCenter.dy);
  final distance = delta.distance;
  final metrics = ThrowMetrics(
    velocity: distance / math.max(1, duration.inMilliseconds),
    direction: distance == 0 ? 0 : math.atan2(delta.dy, delta.dx),
    distance: distance,
    accuracy: (impact - targetCenter).distance,
    delta: delta,
  );
  final quality = upward < kMinSwipeDistance
      ? ThrowQuality.miss
      : qualityFromMetrics(
          metrics,
          targetRadius: targetRadius,
          thresholds: thresholds.normalizedFor(screenSize),
        );
  return (metrics: metrics, quality: quality, impact: impact);
}

/// Quality of a swipe from [start] to [end] aimed at [targetCenter].
///
/// * shorter than [kMinSwipeDistance] or pointing downward → [ThrowQuality.miss]
/// * otherwise by accuracy (distance from [end] to [targetCenter], minus
///   [targetRadius]) against [thresholds]; farther than `good` → MISS.
ThrowQuality calculateThrowQuality({
  required Offset start,
  required Offset end,
  required Offset targetCenter,
  double targetRadius = 0,
  ThrowThresholds thresholds = const ThrowThresholds(),
}) => evaluateThrow(
  start: start,
  end: end,
  targetCenter: targetCenter,
  duration: Duration.zero,
  targetRadius: targetRadius,
  thresholds: thresholds,
).quality;

/// Like [calculateThrowQuality] with [thresholds] scaled by
/// `min(screenSize.width, screenSize.height) / 400`.
ThrowQuality calculateThrowQualityNormalized({
  required Offset start,
  required Offset end,
  required Offset targetCenter,
  required Size screenSize,
  double targetRadius = 0,
  ThrowThresholds thresholds = const ThrowThresholds(),
}) => calculateThrowQuality(
  start: start,
  end: end,
  targetCenter: targetCenter,
  targetRadius: targetRadius,
  thresholds: thresholds.normalizedFor(screenSize),
);

/// Full evaluation (metrics + quality) of a swipe. Pass [screenSize] to
/// normalize [thresholds] by screen size.
ThrowEvaluation evaluateThrow({
  required Offset start,
  required Offset end,
  required Offset targetCenter,
  required Duration duration,
  double targetRadius = 0,
  ThrowThresholds thresholds = const ThrowThresholds(),
  Size? screenSize,
}) {
  final metrics = ThrowMetrics.fromSwipe(
    start: start,
    end: end,
    duration: duration,
    targetCenter: targetCenter,
  );
  final effective = screenSize == null
      ? thresholds
      : thresholds.normalizedFor(screenSize);
  return (
    metrics: metrics,
    quality: qualityFromMetrics(
      metrics,
      targetRadius: targetRadius,
      thresholds: effective,
    ),
  );
}

/// Maps already-computed [metrics] to a [ThrowQuality].
ThrowQuality qualityFromMetrics(
  ThrowMetrics metrics, {
  double targetRadius = 0,
  ThrowThresholds thresholds = const ThrowThresholds(),
}) {
  if (metrics.isNegligible || metrics.isDownward) return ThrowQuality.miss;
  final error = math.max(0.0, metrics.accuracy - math.max(0.0, targetRadius));
  if (error <= thresholds.excellent) return ThrowQuality.excellent;
  if (error <= thresholds.great) return ThrowQuality.great;
  if (error <= thresholds.good) return ThrowQuality.good;
  return ThrowQuality.miss;
}
