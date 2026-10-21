import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/config/campus_config.dart';
import 'package:profesor_go/core/location/lat_lng.dart';
import 'package:profesor_go/core/location/location_service.dart';
import 'package:profesor_go/core/location/mock_location_service.dart';

void main() {
  test('demo path lies inside the campus bounds', () {
    for (final p in CampusConfig.demoPath) {
      expect(CampusConfig.bounds.contains(p), isTrue, reason: '$p');
    }
    final o = CampusConfig.toMapOffset(CampusConfig.bounds.center);
    expect(o.dx, closeTo(CampusConfig.mapWidth / 2, 1e-6));
    expect(o.dy, closeTo(CampusConfig.mapHeight / 2, 1e-6));
    final back = CampusConfig.fromMapOffset(o);
    expect(back.latitude, closeTo(CampusConfig.bounds.center.latitude, 1e-9));
  });

  test('walks the path, teleports and resumes', () async {
    final service = MockLocationService(stepInterval: const Duration(days: 1));
    final received = <LatLng>[];
    final sub = service.positions().listen(received.add);
    await Future<void>.delayed(Duration.zero);
    expect(received, [CampusConfig.demoPath.first]);

    service.step();
    expect(service.current, CampusConfig.demoPath[1]);

    const somewhere = LatLng(40.4520, -3.7260);
    service.teleport(somewhere);
    expect(service.isWalking, isFalse);
    service.step(); // ignored while paused
    expect(service.current, somewhere);

    service.resumeWalk();
    expect(service.isWalking, isTrue);
    service.step();
    expect(CampusConfig.demoPath, contains(service.current));

    await Future<void>.delayed(Duration.zero);
    expect(received.length, 4);
    expect(await service.checkAndRequest(), LocationStatus.available);
    await sub.cancel();
    await service.dispose();
  });

  test('LatLng distance is roughly right', () {
    const a = LatLng(40.0, -3.0);
    const b = LatLng(40.001, -3.0);
    expect(a.distanceTo(b), closeTo(111, 2));
  });
}
