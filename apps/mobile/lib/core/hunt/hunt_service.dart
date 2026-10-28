import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';
import '../location/lat_lng.dart';

class HuntPublisher {
  const HuntPublisher({required this.professorId, required this.professorName});

  final String professorId;
  final String professorName;

  factory HuntPublisher.fromJson(Map<String, dynamic> json) {
    final professor = json['professors'];
    return HuntPublisher(
      professorId: json['professor_id'] as String,
      professorName: professor is Map
          ? (professor['display_name'] as String? ?? 'Profesor')
          : 'Profesor',
    );
  }
}

class HuntSession {
  const HuntSession({
    required this.id,
    required this.professorId,
    required this.professorName,
    required this.startedAt,
    required this.endsAt,
    this.stoppedAt,
    this.position,
    this.accuracyMeters,
    this.locatedAt,
  });

  final String id;
  final String professorId;
  final String professorName;
  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime? stoppedAt;
  final LatLng? position;
  final double? accuracyMeters;
  final DateTime? locatedAt;

  bool isActiveAt(DateTime now) =>
      stoppedAt == null && !now.isBefore(startedAt) && now.isBefore(endsAt);

  bool hasFreshLocationAt(DateTime now) =>
      isActiveAt(now) &&
      position != null &&
      locatedAt != null &&
      !now.difference(locatedAt!).isNegative &&
      now.difference(locatedAt!) < const Duration(seconds: 30);

  factory HuntSession.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final professor = json['professors'];
    return HuntSession(
      id: json['id'] as String,
      professorId: json['professor_id'] as String,
      professorName: professor is Map
          ? (professor['display_name'] as String? ?? 'Profesor')
          : 'Profesor',
      startedAt: DateTime.parse(json['started_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      stoppedAt: DateTime.tryParse(json['stopped_at'] as String? ?? ''),
      position: latitude != null && longitude != null
          ? LatLng(latitude, longitude)
          : null,
      accuracyMeters: (json['accuracy_m'] as num?)?.toDouble(),
      locatedAt: DateTime.tryParse(json['located_at'] as String? ?? ''),
    );
  }
}

class HuntCheckin {
  const HuntCheckin({
    required this.sessionId,
    required this.professorId,
    required this.checkedInAt,
    required this.alreadyRegistered,
  });

  final String sessionId;
  final String professorId;
  final DateTime checkedInAt;
  final bool alreadyRegistered;

  factory HuntCheckin.fromJson(Map<String, dynamic> json) => HuntCheckin(
    sessionId: json['session_id'] as String,
    professorId: json['professor_id'] as String,
    checkedInAt: DateTime.parse(json['checked_in_at'] as String),
    alreadyRegistered: json['already_registered'] as bool? ?? false,
  );
}

abstract class HuntService {
  Future<HuntPublisher?> myPublisher();
  Future<HuntSession?> myActiveSession();
  Future<List<HuntSession>> activeSessions();
  Future<HuntSession> start(String professorId);
  Future<HuntSession> updateLocation(
    String sessionId,
    LatLng position,
    double accuracyMeters,
  );
  Future<bool> stop(String sessionId);
  Future<HuntCheckin?> checkIn(String tagIdentifier);
  Future<HuntCheckin?> checkInQr(String qrCode);
}

class SupabaseHuntService implements HuntService {
  SupabaseHuntService(this._client);

  final SupabaseClient _client;

  static const _sessionColumns =
      'id, professor_id, publisher_id, started_at, ends_at, stopped_at, '
      'latitude, longitude, accuracy_m, located_at, professors(display_name)';

  @override
  Future<HuntPublisher?> myPublisher() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('hunt_publishers')
          .select('professor_id, professors(display_name)')
          .eq('user_id', user.id)
          .maybeSingle();
      return row == null ? null : HuntPublisher.fromJson(row);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  @override
  Future<HuntSession?> myActiveSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('hunt_sessions')
          .select(_sessionColumns)
          .eq('publisher_id', user.id)
          .isFilter('stopped_at', null)
          .gt('ends_at', DateTime.now().toUtc().toIso8601String())
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : HuntSession.fromJson(row);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  @override
  Future<List<HuntSession>> activeSessions() async {
    final now = DateTime.now().toUtc();
    try {
      final rows = await _client
          .from('hunt_sessions')
          .select(_sessionColumns)
          .isFilter('stopped_at', null)
          .gt('ends_at', now.toIso8601String())
          .gt(
            'located_at',
            now.subtract(const Duration(seconds: 30)).toIso8601String(),
          )
          .order('started_at', ascending: false)
          .limit(20);
      return rows
          .map(HuntSession.fromJson)
          .where((session) => session.hasFreshLocationAt(now))
          .toList(growable: false);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  @override
  Future<HuntSession> start(String professorId) async {
    final row = await _rpc('start_campus_hunt', {
      'p_professor_id': professorId,
    });
    return HuntSession.fromJson(row!);
  }

  @override
  Future<HuntSession> updateLocation(
    String sessionId,
    LatLng position,
    double accuracyMeters,
  ) async {
    final row = await _rpc('update_campus_hunt_location', {
      'p_session_id': sessionId,
      'p_latitude': position.latitude,
      'p_longitude': position.longitude,
      'p_accuracy_m': accuracyMeters,
    });
    return HuntSession.fromJson(row!);
  }

  @override
  Future<bool> stop(String sessionId) async {
    try {
      final result = await _client.rpc<Object?>(
        'stop_campus_hunt',
        params: {'p_session_id': sessionId},
      );
      return result == true;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  @override
  Future<HuntCheckin?> checkIn(String tagIdentifier) async {
    final row = await _rpc('check_in_campus_hunt', {
      'p_tag_identifier': tagIdentifier,
    });
    return row == null ? null : HuntCheckin.fromJson(row);
  }

  @override
  Future<HuntCheckin?> checkInQr(String qrCode) async {
    final row = await _rpc('check_in_campus_hunt_qr', {'p_qr_code': qrCode});
    return row == null ? null : HuntCheckin.fromJson(row);
  }

  Future<Map<String, dynamic>?> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    try {
      final result = await _client.rpc<Object?>(name, params: params);
      if (result == null) return null;
      if (result is Map) return result.cast<String, dynamic>();
      throw AppException.fromCode(AppException.serverUnavailable);
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
