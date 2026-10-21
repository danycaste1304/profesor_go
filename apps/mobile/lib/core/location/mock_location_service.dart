import 'dart:async';

import '../config/campus_config.dart';
import 'lat_lng.dart';
import 'location_service.dart';

/// [LocationService] that walks [CampusConfig.demoPath] in a loop
/// (one step per [stepInterval]) and supports [teleport] for tests / debug.
class MockLocationService implements LocationService {
  MockLocationService({
    List<LatLng>? path,
    this.stepInterval = const Duration(seconds: 1),
    this._status = LocationStatus.available,
    bool autoWalk = true,
  })  : _path = path ?? CampusConfig.demoPath,
        _walking = autoWalk {
    assert(_path.isNotEmpty, 'demo path must not be empty');
    _current = _path.first;
    _controller = StreamController<LatLng>.broadcast(
      onListen: _startTimer,
      onCancel: _stopTimer,
    );
  }

  final List<LatLng> _path;
  final Duration stepInterval;
  LocationStatus _status;
  bool _walking;
  int _index = 0;
  late LatLng _current;
  late final StreamController<LatLng> _controller;
  Timer? _timer;

  /// Last emitted position.
  LatLng get current => _current;

  /// Whether the automatic walk along the demo path is running.
  bool get isWalking => _walking;

  /// Simulates a permission outcome for the next [checkAndRequest].
  set statusOverride(LocationStatus value) => _status = value;

  @override
  Stream<LatLng> positions() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<LocationStatus> checkAndRequest() async => _status;

  /// Jumps to [position] and pauses the automatic walk. Call [resumeWalk] to
  /// continue along the demo path from the closest point.
  void teleport(LatLng position) {
    _walking = false;
    _emit(position);
  }

  /// Resumes walking from the path point closest to the current position.
  void resumeWalk() {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < _path.length; i++) {
      final d = _path[i].distanceTo(_current);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    _index = best;
    _walking = true;
  }

  /// Advances one step immediately (useful in tests without waiting).
  void step() {
    if (!_walking) return;
    _index = (_index + 1) % _path.length;
    _emit(_path[_index]);
  }

  void _emit(LatLng p) {
    _current = p;
    if (!_controller.isClosed) _controller.add(p);
  }

  void _startTimer() {
    _timer ??= Timer.periodic(stepInterval, (_) => step());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    _stopTimer();
    await _controller.close();
  }
}
