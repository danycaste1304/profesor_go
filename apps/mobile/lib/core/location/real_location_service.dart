import 'package:geolocator/geolocator.dart';

import '../errors/app_exception.dart';
import 'lat_lng.dart';
import 'location_service.dart';

/// [LocationService] backed by `geolocator`.
class RealLocationService implements LocationService {
  RealLocationService({this.distanceFilterMeters = 3});

  final int distanceFilterMeters;

  @override
  Stream<LatLng> positions() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    ).map((p) => LatLng(p.latitude, p.longitude)).handleError((Object e) {
      if (e is LocationServiceDisabledException) {
        throw AppException.fromCode(AppException.locationDisabled, cause: e);
      }
      if (e is PermissionDeniedException) {
        throw AppException.fromCode(AppException.locationDenied, cause: e);
      }
      throw AppException.fromCode(AppException.locationDenied, cause: e);
    });
  }

  @override
  Future<LocationStatus> checkAndRequest() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationStatus.serviceDisabled;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          LocationStatus.available,
        LocationPermission.deniedForever => LocationStatus.deniedForever,
        LocationPermission.denied ||
        LocationPermission.unableToDetermine =>
          LocationStatus.denied,
      };
    } catch (_) {
      return LocationStatus.denied;
    }
  }
}
