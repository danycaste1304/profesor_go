import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/location/lat_lng.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/mock_location_service.dart';
import '../domain/campus_map_config.dart';

/// Map configuration used by the controller and the screen. Override it in
/// tests or once the real background / bounds are available.
final campusMapConfigProvider = Provider<CampusMapConfig>(
  (ref) => CampusMapConfig.defaults,
);

/// Opens the system screen where the user can fix a location [status];
/// resolves to false when it could not be opened.
typedef SettingsOpener = Future<bool> Function(LocationStatus status);

/// Injectable so tests do not touch the geolocator platform channel.
final settingsOpenerProvider = Provider<SettingsOpener>(
  (ref) => openSystemLocationSettings,
);

/// Default [SettingsOpener]: the location settings when the service is off,
/// the app settings (permissions) otherwise. Never throws.
Future<bool> openSystemLocationSettings(LocationStatus status) async {
  try {
    return status == LocationStatus.serviceDisabled
        ? await Geolocator.openLocationSettings()
        : await Geolocator.openAppSettings();
  } catch (_) {
    return false;
  }
}

/// Immutable view state of the campus map. Only the *latest* position is
/// kept: no location history is ever stored.
@immutable
class MapState {
  const MapState({
    this.status,
    this.current,
    this.simulating = false,
    this.canSimulate = false,
    this.config = CampusMapConfig.defaults,
  });

  /// Result of the permission / service check; `null` while checking.
  final LocationStatus? status;

  /// Latest known position (kept while a re-check is in progress).
  final LatLng? current;

  /// Demo mode: whether the mock service is walking the demo path.
  final bool simulating;

  /// Demo mode: whether the "simular movimiento" toggle applies.
  final bool canSimulate;
  final CampusMapConfig config;

  bool get isChecking => status == null;
  bool get isAvailable => status == LocationStatus.available;

  /// Avatar position in logical map units, `null` without a fix.
  Offset? get mapOffset {
    final p = current;
    return p == null ? null : config.toMapOffset(p);
  }

  bool get isInsideCampus {
    final p = current;
    return p != null && config.contains(p);
  }

  /// Spanish explanation when the position is unavailable, `null` otherwise.
  String? get message => switch (status) {
        null || LocationStatus.available => null,
        LocationStatus.denied => AppException.messages[AppException.locationDenied],
        LocationStatus.deniedForever =>
          'El permiso de ubicación está bloqueado. Actívalo en los ajustes '
              'del móvil para verte en el mapa.',
        LocationStatus.serviceDisabled =>
          '${AppException.messages[AppException.locationDisabled]} '
              'Actívala para verte en el mapa.',
      };

  /// Whether an "Abrir ajustes" action makes sense for [status].
  bool get canOpenSettings =>
      status == LocationStatus.denied ||
      status == LocationStatus.deniedForever ||
      status == LocationStatus.serviceDisabled;

  MapState copyWith({
    LocationStatus? status,
    bool clearStatus = false,
    LatLng? current,
    bool? simulating,
    bool? canSimulate,
    CampusMapConfig? config,
  }) =>
      MapState(
        status: clearStatus ? null : (status ?? this.status),
        current: current ?? this.current,
        simulating: simulating ?? this.simulating,
        canSimulate: canSimulate ?? this.canSimulate,
        config: config ?? this.config,
      );

  @override
  bool operator ==(Object other) =>
      other is MapState &&
      other.status == status &&
      other.current == current &&
      other.simulating == simulating &&
      other.canSimulate == canSimulate &&
      identical(other.config, config);

  @override
  int get hashCode =>
      Object.hash(status, current, simulating, canSimulate, config);
}

final mapControllerProvider =
    NotifierProvider<MapController, MapState>(MapController.new);

/// Subscribes to [LocationService.positions] after a successful
/// [LocationService.checkAndRequest] and projects the position onto the map.
class MapController extends Notifier<MapState> {
  StreamSubscription<LatLng>? _subscription;
  int _attempt = 0;

  @override
  MapState build() {
    final service = ref.watch(locationServiceProvider);
    final config = ref.watch(campusMapConfigProvider);
    ref.onDispose(_cancelSubscription);

    final mock = service is MockLocationService ? service : null;
    unawaited(_start(service));
    return MapState(
      config: config,
      canSimulate: AppConfig.isDemoMode && mock != null,
      simulating: mock?.isWalking ?? false,
    );
  }

  /// Re-runs the permission check and re-subscribes (e.g. after the user
  /// comes back from the settings screen).
  void retry() {
    state = state.copyWith(clearStatus: true);
    unawaited(_start(ref.read(locationServiceProvider)));
  }

  /// Opens the system screen where the user can fix the current problem
  /// (see [openSystemLocationSettings]). Returns false when it failed.
  Future<bool> openSettings() =>
      ref.read(settingsOpenerProvider)(state.status ?? LocationStatus.denied);

  /// Demo mode only: starts / pauses the mock walk along the demo path.
  void setSimulation(bool enabled) {
    final service = ref.read(locationServiceProvider);
    if (service is! MockLocationService) return;
    if (enabled) {
      service.resumeWalk();
    } else {
      service.teleport(service.current); // pauses the walk in place
    }
    state = state.copyWith(simulating: service.isWalking);
  }

  Future<void> _start(LocationService service) async {
    _cancelSubscription();
    final attempt = ++_attempt;

    LocationStatus status;
    try {
      status = await service.checkAndRequest();
    } catch (error) {
      status = _statusFromError(error);
    }
    if (!_isCurrent(attempt)) return;
    state = state.copyWith(status: status);
    if (status != LocationStatus.available) return;

    _subscription = service.positions().listen(
      (position) {
        if (_isCurrent(attempt)) state = state.copyWith(current: position);
      },
      onError: (Object error) {
        if (_isCurrent(attempt)) {
          state = state.copyWith(status: _statusFromError(error));
        }
      },
    );
  }

  bool _isCurrent(int attempt) => ref.mounted && attempt == _attempt;

  void _cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  static LocationStatus _statusFromError(Object error) {
    final e = AppException.from(error);
    return e.code == AppException.locationDisabled
        ? LocationStatus.serviceDisabled
        : LocationStatus.denied;
  }
}
