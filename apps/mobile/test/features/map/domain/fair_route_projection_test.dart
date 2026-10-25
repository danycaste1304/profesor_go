import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/config/app_config.dart';
import 'package:profesor_go/core/location/lat_lng.dart';
import 'package:profesor_go/features/map/domain/campus_map_config.dart';
import 'package:profesor_go/features/map/domain/fair_route_projection.dart';
import 'package:profesor_go/features/map/presentation/map_controller.dart';

void main() {
  const route = FairRouteProjection.usfq;

  test('the two organizer pins land on the tent and laboratory entrance', () {
    expect(route.tent.distanceTo(route.laboratoryEntrance), closeTo(128.5, 1));
    expect(route.contains(route.tent), isTrue);
    expect(route.contains(route.laboratoryEntrance), isTrue);
    expect(route.toMapOffset(route.tent), const Offset(250, 1120));
    expect(route.toMapOffset(route.laboratoryEntrance), const Offset(665, 805));
  });

  test('a position between the pins moves along the illustrated path', () {
    final midpoint = LatLng(
      (route.tent.latitude + route.laboratoryEntrance.latitude) / 2,
      (route.tent.longitude + route.laboratoryEntrance.longitude) / 2,
    );
    final atQuarter = LatLng(
      route.tent.latitude * 0.75 + route.laboratoryEntrance.latitude * 0.25,
      route.tent.longitude * 0.75 + route.laboratoryEntrance.longitude * 0.25,
    );
    expect(route.contains(midpoint), isTrue);
    expect(
      route.toMapOffset(atQuarter).dx,
      lessThan(route.toMapOffset(midpoint).dx),
    );
    expect(route.toMapOffset(midpoint).dx, inInclusiveRange(250, 665));
    expect(route.toMapOffset(midpoint).dy, inInclusiveRange(805, 1120));
  });

  test('distant positions are not projected onto the fair route', () {
    expect(route.contains(const LatLng(40.452, -3.727)), isFalse);
    expect(route.contains(const LatLng(-0.1955, -78.436)), isFalse);
    expect(route.contains(const LatLng(-0.19688, -78.437)), isFalse);
    expect(route.contains(const LatLng(double.nan, 0)), isFalse);
  });

  test('production map uses the route while demo keeps its own bounds', () {
    expect(CampusMapConfig.production.isApproximate, isTrue);
    expect(CampusMapConfig.production.contains(route.tent), isTrue);
    expect(
      CampusMapConfig.production.toMapOffset(route.tent),
      const Offset(250, 1120),
    );
    expect(CampusMapConfig.defaults.isApproximate, isFalse);
    expect(CampusMapConfig.defaults.contains(route.tent), isFalse);
  });

  test('the map provider selects the correct projection for this build', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(campusMapConfigProvider).isApproximate,
      !AppConfig.isDemoMode,
    );
  });
}
