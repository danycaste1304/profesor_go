import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../../core/config/campus_config.dart';

/// Converts a GPS coordinate into a logical map offset.
///
/// Linear interpolation inside [bounds]: the north-west corner maps to
/// `(0, 0)` and the south-east corner to `(mapWidth, mapHeight)`. Points
/// outside the bounds are clamped to the nearest edge, so the result always
/// lies in `[0, mapWidth] x [0, mapHeight]`.
///
/// Degenerate input never divides by zero: a collapsed axis (north == south
/// or east == west) and NaN coordinates map to the middle of that axis, and a
/// negative map size is treated as zero.
Offset gpsToMapCoordinates({
  required double latitude,
  required double longitude,
  required CampusBounds bounds,
  required double mapWidth,
  required double mapHeight,
}) {
  final width = _nonNegative(mapWidth);
  final height = _nonNegative(mapHeight);
  final fx = _fraction(longitude, from: bounds.west, to: bounds.east);
  final fy = _fraction(latitude, from: bounds.north, to: bounds.south);
  return Offset(fx * width, fy * height);
}

/// True when the coordinate lies inside [bounds] (edges included). Works
/// even if the rectangle was declared with swapped corners; NaN is outside.
bool isInsideBounds({
  required double latitude,
  required double longitude,
  required CampusBounds bounds,
}) {
  final minLat = math.min(bounds.north, bounds.south);
  final maxLat = math.max(bounds.north, bounds.south);
  final minLng = math.min(bounds.east, bounds.west);
  final maxLng = math.max(bounds.east, bounds.west);
  return latitude >= minLat &&
      latitude <= maxLat &&
      longitude >= minLng &&
      longitude <= maxLng;
}

/// Position of [value] between [from] (0) and [to] (1), clamped to `[0, 1]`.
/// Returns 0.5 when the span is zero or any input is NaN.
double _fraction(double value, {required double from, required double to}) {
  final span = to - from;
  if (span == 0 || span.isNaN || value.isNaN) return 0.5;
  final fraction = (value - from) / span;
  if (fraction.isNaN) return 0.5;
  return fraction.clamp(0.0, 1.0);
}

double _nonNegative(double v) => v.isNaN || v < 0 ? 0 : v;
