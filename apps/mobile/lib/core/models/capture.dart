import 'throw_quality.dart';

/// Row of `public.captures` (CONTRACTS §2).
class Capture {
  const Capture({
    required this.id,
    required this.userId,
    required this.professorId,
    required this.throwQuality,
    required this.capturedAt,
    this.encounterId,
  });

  factory Capture.fromJson(Map<String, dynamic> json) => Capture(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        professorId: json['professor_id'] as String,
        encounterId: json['encounter_id'] as String?,
        throwQuality: ThrowQuality.parse(json['throw_quality'] as String),
        capturedAt: json['captured_at'] is String
            ? DateTime.parse(json['captured_at'] as String).toUtc()
            : DateTime.now().toUtc(),
      );

  final String id;
  final String userId;
  final String professorId;
  final String? encounterId;
  final ThrowQuality throwQuality;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'professor_id': professorId,
        'encounter_id': encounterId,
        'throw_quality': throwQuality.wireValue,
        'captured_at': capturedAt.toUtc().toIso8601String(),
      };

  Capture copyWith({
    String? id,
    String? userId,
    String? professorId,
    String? encounterId,
    ThrowQuality? throwQuality,
    DateTime? capturedAt,
  }) =>
      Capture(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        professorId: professorId ?? this.professorId,
        encounterId: encounterId ?? this.encounterId,
        throwQuality: throwQuality ?? this.throwQuality,
        capturedAt: capturedAt ?? this.capturedAt,
      );

  @override
  bool operator ==(Object other) => other is Capture && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Capture($id, professor=$professorId)';
}
