import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/config/campus_config.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/location/lat_lng.dart';
import 'package:profesor_go/core/location/location_service.dart';
import 'package:profesor_go/core/location/mock_location_service.dart';
import 'package:profesor_go/features/map/presentation/map_controller.dart';

/// Service whose position stream fails, to exercise the error path.
class _FailingLocationService implements LocationService {
  _FailingLocationService(this.error);

  final Object error;

  @override
  Future<LocationStatus> checkAndRequest() async => LocationStatus.available;

  @override
  Stream<LatLng> positions() => Stream<LatLng>.error(error);
}

void main() {
  ProviderContainer makeContainer(LocationService service) {
    final container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('checks permission, subscribes and projects the latest position',
      () async {
    final service = MockLocationService(
      stepInterval: const Duration(days: 1),
      autoWalk: false,
    );
    addTearDown(service.dispose);
    final container = makeContainer(service);

    final initial = container.read(mapControllerProvider);
    expect(initial.isChecking, isTrue);
    expect(initial.current, isNull);
    expect(initial.mapOffset, isNull);
    expect(initial.canSimulate, isTrue); // DEMO_MODE defaults to true
    expect(initial.simulating, isFalse);

    await pumpEventQueue();
    var state = container.read(mapControllerProvider);
    expect(state.status, LocationStatus.available);
    expect(state.current, CampusConfig.demoPath.first);
    expect(state.isInsideCampus, isTrue);
    expect(state.mapOffset, CampusConfig.toMapOffset(CampusConfig.demoPath.first));
    expect(state.message, isNull);

    const outside = LatLng(0, 0);
    service.teleport(outside);
    await pumpEventQueue();
    state = container.read(mapControllerProvider);
    expect(state.current, outside);
    expect(state.isInsideCampus, isFalse);
    expect(state.mapOffset!.dx, inInclusiveRange(0, CampusConfig.mapWidth));
    expect(state.mapOffset!.dy, inInclusiveRange(0, CampusConfig.mapHeight));
  });

  test('denied / deniedForever / serviceDisabled expose Spanish messages',
      () async {
    for (final status in [
      LocationStatus.denied,
      LocationStatus.deniedForever,
      LocationStatus.serviceDisabled,
    ]) {
      final service = MockLocationService(
        stepInterval: const Duration(days: 1),
        autoWalk: false,
      )..statusOverride = status;
      addTearDown(service.dispose);
      final container = makeContainer(service);
      container.read(mapControllerProvider);
      await pumpEventQueue();

      final state = container.read(mapControllerProvider);
      expect(state.status, status);
      expect(state.current, isNull, reason: 'never subscribes without permission');
      expect(state.message, isNotNull);
      expect(state.message, contains('ubicación'));
      expect(state.canOpenSettings, isTrue);
    }
  });

  test('retry re-runs the check after the permission was granted', () async {
    final service = MockLocationService(
      stepInterval: const Duration(days: 1),
      autoWalk: false,
    )..statusOverride = LocationStatus.denied;
    addTearDown(service.dispose);
    final container = makeContainer(service);
    container.read(mapControllerProvider);
    await pumpEventQueue();
    expect(container.read(mapControllerProvider).status, LocationStatus.denied);

    service.statusOverride = LocationStatus.available;
    container.read(mapControllerProvider.notifier).retry();
    expect(container.read(mapControllerProvider).isChecking, isTrue);
    await pumpEventQueue();
    final state = container.read(mapControllerProvider);
    expect(state.isAvailable, isTrue);
    expect(state.current, service.current);
  });

  test('a failing position stream downgrades the status', () async {
    final container = makeContainer(
      _FailingLocationService(
        AppException.fromCode(AppException.locationDisabled),
      ),
    );
    container.read(mapControllerProvider);
    await pumpEventQueue();
    final state = container.read(mapControllerProvider);
    expect(state.status, LocationStatus.serviceDisabled);
    expect(state.message, contains('desactivada'));
  });

  test('setSimulation starts and pauses the mock walk', () async {
    final service = MockLocationService(
      stepInterval: const Duration(days: 1),
      autoWalk: false,
    );
    addTearDown(service.dispose);
    final container = makeContainer(service);
    container.read(mapControllerProvider);
    await pumpEventQueue();

    final notifier = container.read(mapControllerProvider.notifier);
    notifier.setSimulation(true);
    expect(service.isWalking, isTrue);
    expect(container.read(mapControllerProvider).simulating, isTrue);

    service.step();
    await pumpEventQueue();
    expect(container.read(mapControllerProvider).current, CampusConfig.demoPath[1]);

    notifier.setSimulation(false);
    expect(service.isWalking, isFalse);
    expect(container.read(mapControllerProvider).simulating, isFalse);
  });

  test('openSettings forwards the current status to the opener', () async {
    final service = MockLocationService(
      stepInterval: const Duration(days: 1),
      autoWalk: false,
    )..statusOverride = LocationStatus.serviceDisabled;
    addTearDown(service.dispose);
    final requested = <LocationStatus>[];
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(service),
        settingsOpenerProvider.overrideWithValue((status) async {
          requested.add(status);
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(mapControllerProvider);
    await pumpEventQueue();
    final opened =
        await container.read(mapControllerProvider.notifier).openSettings();
    expect(opened, isTrue);
    expect(requested, [LocationStatus.serviceDisabled]);
  });

  test('the default opener never throws without a platform', () async {
    expect(await openSystemLocationSettings(LocationStatus.denied), isFalse);
    expect(
      await openSystemLocationSettings(LocationStatus.serviceDisabled),
      isFalse,
    );
  });

  test('disposing the container cancels the position subscription', () async {
    final controller = StreamController<LatLng>.broadcast();
    addTearDown(controller.close);
    final service = _StreamLocationService(controller.stream);
    final container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(service)],
    );
    container.read(mapControllerProvider);
    await pumpEventQueue();
    expect(controller.hasListener, isTrue);
    container.dispose();
    await pumpEventQueue();
    expect(controller.hasListener, isFalse);
  });
}

class _StreamLocationService implements LocationService {
  _StreamLocationService(this.stream);

  final Stream<LatLng> stream;

  @override
  Future<LocationStatus> checkAndRequest() async => LocationStatus.available;

  @override
  Stream<LatLng> positions() => stream;
}
