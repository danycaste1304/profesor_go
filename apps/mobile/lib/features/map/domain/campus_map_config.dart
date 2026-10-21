import 'dart:ui' show Offset, Size;

import '../../../core/config/campus_config.dart';
import '../../../core/location/lat_lng.dart';
import 'gps_to_map.dart';

/// Everything the campus map needs to know about its background and the
/// geo → pixel projection. Defaults come from [CampusConfig] (core), so the
/// map feature and the mock location service always agree.
///
/// The bundled pixel-art map is a fictional demo campus. Replace the
/// placeholder [CampusConfig.bounds] and this asset with surveyed campus data
/// for an actual fair. [mapWidth] x [mapHeight] must keep the image's ratio.
class CampusMapConfig {
  const CampusMapConfig({
    this.bounds = CampusConfig.bounds,
    this.mapWidth = CampusConfig.mapWidth,
    this.mapHeight = CampusConfig.mapHeight,
    this.backgroundAssetPath = defaultBackgroundAssetPath,
  });

  /// Bundled original pixel-art map; replace with final campus artwork.
  static const String defaultBackgroundAssetPath = 'assets/map/campus_map.png';

  /// Core defaults: placeholder bounds, 900x1200 logical px, pixel-art map.
  static const CampusMapConfig defaults = CampusMapConfig();

  final CampusBounds bounds;

  /// Logical size of the map canvas (independent of the screen).
  final double mapWidth;
  final double mapHeight;

  /// Asset path of the background image. `null` (or an asset that fails to
  /// load) means the built-in vector campus painter is used instead.
  final String? backgroundAssetPath;

  Size get mapSize => Size(mapWidth, mapHeight);

  /// Logical map offset of [p] (clamped to the map rectangle).
  Offset toMapOffset(LatLng p) => gpsToMapCoordinates(
    latitude: p.latitude,
    longitude: p.longitude,
    bounds: bounds,
    mapWidth: mapWidth,
    mapHeight: mapHeight,
  );

  /// True when [p] lies inside the campus rectangle.
  bool contains(LatLng p) => isInsideBounds(
    latitude: p.latitude,
    longitude: p.longitude,
    bounds: bounds,
  );

  CampusMapConfig copyWith({
    CampusBounds? bounds,
    double? mapWidth,
    double? mapHeight,
    String? backgroundAssetPath,
  }) => CampusMapConfig(
    bounds: bounds ?? this.bounds,
    mapWidth: mapWidth ?? this.mapWidth,
    mapHeight: mapHeight ?? this.mapHeight,
    backgroundAssetPath: backgroundAssetPath ?? this.backgroundAssetPath,
  );
}
