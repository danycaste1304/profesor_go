import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../../core/location/lat_lng.dart';

/// Approximate player position on the illustrated carpa → laboratory route.
///
/// The two geographic anchors came from organizer-shared Google Maps pins.
/// They have not been surveyed on site. The drawing is in perspective, so a
/// normal latitude/longitude rectangle would imply false precision; this
/// projection only shows progress along the illustrated route.
class FairRouteProjection {
  const FairRouteProjection({
    required this.tent,
    required this.laboratoryEntrance,
    required this.path,
    this.corridorHalfWidthMeters = 60,
    this.endpointAllowanceMeters = 30,
  });

  static const usfq = FairRouteProjection(
    tent: LatLng(-0.1968714, -78.4364417),
    laboratoryEntrance: LatLng(-0.1968818, -78.4352857),
    path: [
      Offset(250, 1120), // delante de la carpa del Politécnico
      Offset(405, 1030), // camino central de los Cuadrángulos
      Offset(540, 910), // sendero hacia la derecha
      Offset(665, 805), // dirección de la entrada del laboratorio
    ],
  );

  final LatLng tent;
  final LatLng laboratoryEntrance;
  final List<Offset> path;
  final double corridorHalfWidthMeters;
  final double endpointAllowanceMeters;

  /// GPS locations far from the fair route are not drawn on the illustration.
  bool contains(LatLng position) {
    final coordinates = _routeCoordinates(position);
    if (coordinates == null) return false;
    final (along, lateral, length) = coordinates;
    return along >= -endpointAllowanceMeters &&
        along <= length + endpointAllowanceMeters &&
        lateral <= corridorHalfWidthMeters;
  }

  /// Snaps a position to the illustrated route; callers should first check
  /// [contains] so a distant point is never shown as a route endpoint.
  Offset toMapOffset(LatLng position) {
    if (path.isEmpty) return Offset.zero;
    if (path.length == 1) return path.first;
    final coordinates = _routeCoordinates(position);
    if (coordinates == null) return path.first;
    final (along, _, length) = coordinates;
    final progress = (along / length).clamp(0.0, 1.0);

    var pathLength = 0.0;
    for (var i = 1; i < path.length; i++) {
      pathLength += (path[i] - path[i - 1]).distance;
    }
    if (pathLength == 0) return path.first;

    var remaining = pathLength * progress;
    for (var i = 1; i < path.length; i++) {
      final start = path[i - 1];
      final end = path[i];
      final segmentLength = (end - start).distance;
      if (remaining <= segmentLength && segmentLength > 0) {
        return Offset.lerp(start, end, remaining / segmentLength)!;
      }
      remaining -= segmentLength;
    }
    return path.last;
  }

  /// Along-route distance, perpendicular distance and route length in meters.
  (double, double, double)? _routeCoordinates(LatLng position) {
    if (!position.latitude.isFinite || !position.longitude.isFinite) {
      return null;
    }
    final latitudeRadians = tent.latitude * math.pi / 180;
    final metersPerLongitude = 111320 * math.cos(latitudeRadians);
    const metersPerLatitude = 111132.0;
    final routeEast =
        (laboratoryEntrance.longitude - tent.longitude) * metersPerLongitude;
    final routeNorth =
        (laboratoryEntrance.latitude - tent.latitude) * metersPerLatitude;
    final east = (position.longitude - tent.longitude) * metersPerLongitude;
    final north = (position.latitude - tent.latitude) * metersPerLatitude;
    final length = math.sqrt(routeEast * routeEast + routeNorth * routeNorth);
    if (!length.isFinite || length < 1) return null;
    final along = (east * routeEast + north * routeNorth) / length;
    final lateral = (east * routeNorth - north * routeEast).abs() / length;
    return (along, lateral, length);
  }
}
