import 'professor.dart';

/// `encounters.status` (CONTRACTS §1).
enum EncounterStatus {
  active('ACTIVE'),
  success('SUCCESS'),
  failed('FAILED'),
  expired('EXPIRED');

  const EncounterStatus(this.wireValue);
  final String wireValue;

  static EncounterStatus parse(String value) {
    final v = value.trim().toUpperCase();
    return values.firstWhere(
      (s) => s.wireValue == v,
      orElse: () => throw FormatException('Unknown encounter status: $value'),
    );
  }
}

/// An active capture attempt, as returned by `start-encounter`.
class Encounter {
  const Encounter({
    required this.id,
    required this.expiresAt,
    required this.professor,
    this.status = EncounterStatus.active,
    this.createdAt,
  });

  /// Parses the `start-encounter` response (`encounter_id`, `expires_at`,
  /// `professor`) and also tolerates the table row shape (`id`).
  factory Encounter.fromJson(Map<String, dynamic> json) => Encounter(
        id: (json['encounter_id'] ?? json['id']) as String,
        expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
        professor: ProfessorSummary.fromJson(
          (json['professor'] as Map).cast<String, dynamic>(),
        ),
        status: json['status'] is String
            ? EncounterStatus.parse(json['status'] as String)
            : EncounterStatus.active,
        createdAt: json['created_at'] is String
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  final String id;
  final DateTime expiresAt;
  final ProfessorSummary professor;
  final EncounterStatus status;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'encounter_id': id,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'professor': professor.toJson(),
        'status': status.wireValue,
        'created_at': createdAt?.toIso8601String(),
      };

  Encounter copyWith({
    String? id,
    DateTime? expiresAt,
    ProfessorSummary? professor,
    EncounterStatus? status,
    DateTime? createdAt,
  }) =>
      Encounter(
        id: id ?? this.id,
        expiresAt: expiresAt ?? this.expiresAt,
        professor: professor ?? this.professor,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt);

  bool get isExpired => isExpiredAt(DateTime.now());

  /// Time left before expiry (never negative).
  Duration remainingAt(DateTime now) {
    final d = expiresAt.difference(now.toUtc());
    return d.isNegative ? Duration.zero : d;
  }

  Duration get remaining => remainingAt(DateTime.now());

  @override
  bool operator ==(Object other) => other is Encounter && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Encounter($id, ${professor.displayName}, $status)';
}
