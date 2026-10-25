import 'dart:ui' show Offset, Size;

import '../../../core/config/campus_config.dart';
import '../../../core/location/lat_lng.dart';
import 'fair_route_projection.dart';
import 'gps_to_map.dart';

/// Everything the campus map needs to know about its background and the
/// geo → pixel projection. Defaults come from [CampusConfig] (core), so the
/// map feature and the mock location service always agree.
///
/// The demo uses rectangular placeholder bounds. The real fair build uses an
/// approximate route between the organizer's two campus pins because the
/// bundled quadrangles artwork is drawn in perspective.
class CampusMapConfig {
  const CampusMapConfig({
    this.bounds = CampusConfig.bounds,
    this.mapWidth = CampusConfig.mapWidth,
    this.mapHeight = CampusConfig.mapHeight,
    this.backgroundAssetPath = defaultBackgroundAssetPath,
    this.fairRoute,
  });

  /// Bundled quadrangles illustration by the UI teammate.
  static const String defaultBackgroundAssetPath = 'assets/map/campus_map.png';

  /// Core defaults: placeholder bounds, 720x1290 logical px (9:16), pixel-art map.
  static const CampusMapConfig defaults = CampusMapConfig();

  /// On-site coordinates still need validation before this can be treated as
  /// more than a route-level estimate of the player's position.
  static const CampusMapConfig production = CampusMapConfig(
    fairRoute: FairRouteProjection.usfq,
  );

  final CampusBounds bounds;

  /// Logical size of the map canvas (independent of the screen).
  final double mapWidth;
  final double mapHeight;

  /// Asset path of the background image. `null` (or an asset that fails to
  /// load) means the built-in vector campus painter is used instead.
  final String? backgroundAssetPath;
  final FairRouteProjection? fairRoute;

  bool get isApproximate => fairRoute != null;

  Size get mapSize => Size(mapWidth, mapHeight);

  /// Logical map offset of [p]. The real fair build snaps to the route.
  Offset toMapOffset(LatLng p) =>
      fairRoute?.toMapOffset(p) ??
      gpsToMapCoordinates(
        latitude: p.latitude,
        longitude: p.longitude,
        bounds: bounds,
        mapWidth: mapWidth,
        mapHeight: mapHeight,
      );

  /// True when [p] lies inside the configured demo bounds or fair corridor.
  bool contains(LatLng p) =>
      fairRoute?.contains(p) ??
      isInsideBounds(
        latitude: p.latitude,
        longitude: p.longitude,
        bounds: bounds,
      );

  CampusMapConfig copyWith({
    CampusBounds? bounds,
    double? mapWidth,
    double? mapHeight,
    String? backgroundAssetPath,
    FairRouteProjection? fairRoute,
  }) => CampusMapConfig(
    bounds: bounds ?? this.bounds,
    mapWidth: mapWidth ?? this.mapWidth,
    mapHeight: mapHeight ?? this.mapHeight,
    backgroundAssetPath: backgroundAssetPath ?? this.backgroundAssetPath,
    fairRoute: fairRoute ?? this.fairRoute,
  );
}
