import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/hunt/hunt_service.dart';
import 'package:profesor_go/core/location/lat_lng.dart';

void main() {
  final start = DateTime.utc(2026, 10, 29, 15);
  final end = start.add(const Duration(minutes: 30));

  HuntSession session({DateTime? locatedAt, DateTime? stoppedAt}) =>
      HuntSession(
        id: 'session',
        professorId: 'professor',
        professorName: 'Prof. Test',
        startedAt: start,
        endsAt: end,
        stoppedAt: stoppedAt,
        position: const LatLng(-0.1969, -78.4362),
        accuracyMeters: 15,
        locatedAt: locatedAt,
      );

  test('location disappears after 30 seconds, stop, or expiry', () {
    final update = start.add(const Duration(minutes: 2));
    final active = session(locatedAt: update);
    expect(
      active.hasFreshLocationAt(update.add(const Duration(seconds: 29))),
      isTrue,
    );
    expect(
      active.hasFreshLocationAt(update.add(const Duration(seconds: 30))),
      isFalse,
    );
    expect(
      session(locatedAt: update, stoppedAt: update).hasFreshLocationAt(update),
      isFalse,
    );
    expect(
      session(locatedAt: end.subtract(const Duration(seconds: 1)))
          .hasFreshLocationAt(end),
      isFalse,
    );
  });

  test('RPC session without joined professor still parses', () {
    final parsed = HuntSession.fromJson({
      'id': 'session',
      'professor_id': 'professor',
      'started_at': start.toIso8601String(),
      'ends_at': end.toIso8601String(),
      'stopped_at': null,
      'latitude': -0.1969,
      'longitude': -78.4362,
      'accuracy_m': 15,
      'located_at': start.toIso8601String(),
    });
    expect(parsed.professorName, 'Profesor');
    expect(parsed.position, const LatLng(-0.1969, -78.4362));
    expect(
      parsed.hasFreshLocationAt(start.add(const Duration(seconds: 10))),
      isTrue,
    );
  });
}
