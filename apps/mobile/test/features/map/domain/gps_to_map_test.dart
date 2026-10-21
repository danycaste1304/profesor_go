import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/config/campus_config.dart';
import 'package:profesor_go/core/location/lat_lng.dart';
import 'package:profesor_go/features/map/domain/campus_map_config.dart';
import 'package:profesor_go/features/map/domain/gps_to_map.dart';

void main() {
  const bounds = CampusBounds(north: 10, south: 0, east: 20, west: 0);
  const width = 900.0;
  const height = 1200.0;

  Offset project(double lat, double lng, {CampusBounds b = bounds}) =>
      gpsToMapCoordinates(
        latitude: lat,
        longitude: lng,
        bounds: b,
        mapWidth: width,
        mapHeight: height,
      );

  group('gpsToMapCoordinates', () {
    test('corners map to corners', () {
      expect(project(10, 0), Offset.zero); // north-west
      expect(project(10, 20), const Offset(width, 0)); // north-east
      expect(project(0, 0), const Offset(0, height)); // south-west
      expect(project(0, 20), const Offset(width, height)); // south-east
    });

    test('center maps to center', () {
      final o = project(5, 10);
      expect(o.dx, closeTo(width / 2, 1e-9));
      expect(o.dy, closeTo(height / 2, 1e-9));
    });

    test('is linear in between', () {
      final o = project(7.5, 5);
      expect(o.dx, closeTo(width * 0.25, 1e-9));
      expect(o.dy, closeTo(height * 0.25, 1e-9));
    });

    test('out-of-bounds points clamp to the edges', () {
      expect(project(50, -30), Offset.zero);
      expect(project(-50, 999), const Offset(width, height));
      final o = project(5, 999);
      expect(o.dx, width);
      expect(o.dy, closeTo(height / 2, 1e-9));
    });

    test('degenerate bounds never divide by zero', () {
      const flat = CampusBounds(north: 5, south: 5, east: 20, west: 0);
      final o = project(5, 10, b: flat);
      expect(o.dx, closeTo(width / 2, 1e-9));
      expect(o.dy, closeTo(height / 2, 1e-9));
      expect(o.dx.isFinite && o.dy.isFinite, isTrue);

      const point = CampusBounds(north: 5, south: 5, east: 3, west: 3);
      final p = project(99, -99, b: point);
      expect(p, const Offset(width / 2, height / 2));
    });

    test('NaN input and negative map sizes are guarded', () {
      final nan = project(double.nan, double.nan);
      expect(nan.dx.isFinite && nan.dy.isFinite, isTrue);
      final negative = gpsToMapCoordinates(
        latitude: 5,
        longitude: 10,
        bounds: bounds,
        mapWidth: -100,
        mapHeight: -100,
      );
      expect(negative, Offset.zero);
    });

    test('agrees with CampusConfig.toMapOffset for the demo path', () {
      for (final p in CampusConfig.demoPath) {
        final expected = CampusConfig.toMapOffset(p);
        final actual = gpsToMapCoordinates(
          latitude: p.latitude,
          longitude: p.longitude,
          bounds: CampusConfig.bounds,
          mapWidth: CampusConfig.mapWidth,
          mapHeight: CampusConfig.mapHeight,
        );
        expect(actual.dx, closeTo(expected.dx, 1e-6));
        expect(actual.dy, closeTo(expected.dy, 1e-6));
      }
    });
  });

  group('isInsideBounds', () {
    bool inside(double lat, double lng, {CampusBounds b = bounds}) =>
        isInsideBounds(latitude: lat, longitude: lng, bounds: b);

    test('inside, on the edge and outside', () {
      expect(inside(5, 10), isTrue);
      expect(inside(10, 20), isTrue);
      expect(inside(0, 0), isTrue);
      expect(inside(10.0001, 10), isFalse);
      expect(inside(5, -0.0001), isFalse);
      expect(inside(double.nan, 10), isFalse);
    });

    test('works with swapped corners', () {
      const swapped = CampusBounds(north: 0, south: 10, east: 0, west: 20);
      expect(inside(5, 10, b: swapped), isTrue);
      expect(inside(11, 10, b: swapped), isFalse);
    });
  });

  group('CampusMapConfig', () {
    test('defaults mirror CampusConfig and use the bundled pixel map', () {
      const config = CampusMapConfig.defaults;
      expect(config.mapWidth, CampusConfig.mapWidth);
      expect(config.mapHeight, CampusConfig.mapHeight);
      expect(config.backgroundAssetPath, CampusMapConfig.defaultBackgroundAssetPath);
      expect(config.contains(CampusConfig.bounds.center), isTrue);
      final o = config.toMapOffset(CampusConfig.bounds.center);
      expect(o.dx, closeTo(CampusConfig.mapWidth / 2, 1e-6));
      expect(o.dy, closeTo(CampusConfig.mapHeight / 2, 1e-6));
      expect(config.contains(const LatLng(0, 0)), isFalse);
    });

    test('copyWith keeps unspecified values', () {
      final c = CampusMapConfig.defaults.copyWith(
        backgroundAssetPath: CampusMapConfig.defaultBackgroundAssetPath,
      );
      expect(c.backgroundAssetPath, 'assets/map/campus_map.png');
      expect(c.mapSize, CampusConfig.mapSize);
    });
  });
}
