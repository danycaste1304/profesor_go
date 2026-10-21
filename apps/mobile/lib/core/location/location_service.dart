import 'lat_lng.dart';

/// Outcome of a permission / service check.
enum LocationStatus { available, denied, deniedForever, serviceDisabled }

/// Provides the player's position for the campus map.
/// No position history is ever stored.
abstract class LocationService {
  /// Live positions. Subscribe after [checkAndRequest] returned
  /// [LocationStatus.available]; otherwise the stream may error.
  Stream<LatLng> positions();

  /// Checks the service + permission, requesting permission when needed.
  Future<LocationStatus> checkAndRequest();
}
