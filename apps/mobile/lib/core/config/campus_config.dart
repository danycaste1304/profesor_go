import 'dart:ui' show Offset, Size;

import '../location/lat_lng.dart';

/// Geographic rectangle covering the campus / fair grounds.
class CampusBounds {
  const CampusBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;

  LatLng get center => LatLng((north + south) / 2, (east + west) / 2);

  bool contains(LatLng p) =>
      p.latitude <= north &&
      p.latitude >= south &&
      p.longitude <= east &&
      p.longitude >= west;

  /// Clamps a point into the rectangle.
  LatLng clamp(LatLng p) =>
      LatLng(p.latitude.clamp(south, north), p.longitude.clamp(west, east));
}

/// Static campus configuration: bounds, logical map size and the demo path.
abstract final class CampusConfig {
  // TODO_EXTERNAL: replace with the real fair-ground coordinates (WGS84 degrees).
  // Placeholder rectangle of ~300 m x ~400 m; north > south, east > west.
  static const CampusBounds bounds = CampusBounds(
    north: 40.4535,
    south: 40.4508,
    east: -3.7245,
    west: -3.7290,
  );

  /// Logical size of the pixel-art map image / canvas (independent of screen).
  static const double mapWidth = 900;
  static const double mapHeight = 1200;
  static const Size mapSize = Size(mapWidth, mapHeight);

  /// Demo route in the pixel map's open lanes. Keeping it in map coordinates
  /// prevents the avatar from walking across the illustrated rooftops.
  static final List<LatLng> demoPath = List<LatLng>.unmodifiable(
    const <Offset>[
      Offset(450, 340),
      Offset(450, 300),
      Offset(450, 245),
      Offset(450, 180),
      Offset(450, 100),
      Offset(450, 180),
      Offset(450, 260),
      Offset(450, 320),
      Offset(370, 320),
      Offset(290, 320),
      Offset(210, 320),
      Offset(150, 320),
      Offset(210, 320),
      Offset(290, 320),
      Offset(370, 320),
      Offset(450, 320),
      Offset(530, 320),
      Offset(610, 320),
      Offset(690, 320),
      Offset(750, 320),
      Offset(690, 320),
      Offset(610, 320),
      Offset(530, 320),
    ].map(fromMapOffset),
  );

  /// Maps a coordinate to a logical map offset (0,0 = north-west corner).
  /// Points outside the bounds are clamped to the edge.
  static Offset toMapOffset(LatLng p) {
    final c = bounds.clamp(p);
    final dx = (c.longitude - bounds.west) / (bounds.east - bounds.west);
    final dy = (bounds.north - c.latitude) / (bounds.north - bounds.south);
    return Offset(dx * mapWidth, dy * mapHeight);
  }

  /// Inverse of [toMapOffset].
  static LatLng fromMapOffset(Offset o) {
    final fx = (o.dx / mapWidth).clamp(0.0, 1.0);
    final fy = (o.dy / mapHeight).clamp(0.0, 1.0);
    return LatLng(
      bounds.north - fy * (bounds.north - bounds.south),
      bounds.west + fx * (bounds.east - bounds.west),
    );
  }
}
