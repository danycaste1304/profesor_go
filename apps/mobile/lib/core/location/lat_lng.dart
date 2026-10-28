import 'dart:math' as math;

/// Immutable geographic coordinate (degrees).
class LatLng {
  const LatLng(this.latitude, this.longitude, {this.accuracyMeters});

  factory LatLng.fromJson(Map<String, dynamic> json) =>
      LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble());

  final double latitude;
  final double longitude;

  /// GPS uncertainty for the latest fix; never persisted for students.
  final double? accuracyMeters;

  Map<String, dynamic> toJson() => {'lat': latitude, 'lng': longitude};

  /// Great-circle distance in meters (haversine).
  double distanceTo(LatLng other) {
    const earthRadius = 6371000.0;
    final dLat = _rad(other.latitude - latitude);
    final dLng = _rad(other.longitude - longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(latitude)) *
            math.cos(_rad(other.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  @override
  bool operator ==(Object other) =>
      other is LatLng &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracyMeters == accuracyMeters;

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyMeters);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}
