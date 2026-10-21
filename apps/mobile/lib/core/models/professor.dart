import 'rarity.dart';

/// Row of `public.professors` (CONTRACTS §2).
class Professor {
  const Professor({
    required this.id,
    required this.name,
    required this.displayName,
    required this.rarity,
    required this.baseCaptureRate,
    this.description,
    this.spriteUrl,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Professor.fromJson(Map<String, dynamic> json) {
    final rarity = Rarity.parse(json['rarity'] as String);
    return Professor(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['display_name'] as String,
      displayName: json['display_name'] as String,
      description: json['description'] as String?,
      rarity: rarity,
      spriteUrl: json['sprite_url'] as String?,
      active: json['active'] as bool? ?? true,
      baseCaptureRate:
          (json['base_capture_rate'] as num?)?.toDouble() ??
          rarity.defaultCaptureRate,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  final String id;
  final String name;
  final String displayName;
  final String? description;
  final Rarity rarity;
  final String? spriteUrl;
  final bool active;
  final double baseCaptureRate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'display_name': displayName,
        'description': description,
        'rarity': rarity.wireValue,
        'sprite_url': spriteUrl,
        'active': active,
        'base_capture_rate': baseCaptureRate,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Professor copyWith({
    String? id,
    String? name,
    String? displayName,
    String? description,
    Rarity? rarity,
    String? spriteUrl,
    bool? active,
    double? baseCaptureRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Professor(
        id: id ?? this.id,
        name: name ?? this.name,
        displayName: displayName ?? this.displayName,
        description: description ?? this.description,
        rarity: rarity ?? this.rarity,
        spriteUrl: spriteUrl ?? this.spriteUrl,
        active: active ?? this.active,
        baseCaptureRate: baseCaptureRate ?? this.baseCaptureRate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// The reduced shape returned by `start-encounter`.
  ProfessorSummary get summary => ProfessorSummary(
        id: id,
        displayName: displayName,
        rarity: rarity,
        spriteUrl: spriteUrl,
        description: description,
      );

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  @override
  bool operator ==(Object other) => other is Professor && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Professor($id, $displayName, ${rarity.wireValue})';
}

/// Professor shape embedded in the `start-encounter` response (CONTRACTS §4).
class ProfessorSummary {
  const ProfessorSummary({
    required this.id,
    required this.displayName,
    required this.rarity,
    this.spriteUrl,
    this.description,
  });

  factory ProfessorSummary.fromJson(Map<String, dynamic> json) =>
      ProfessorSummary(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        rarity: Rarity.parse(json['rarity'] as String),
        spriteUrl: json['sprite_url'] as String?,
        description: json['description'] as String?,
      );

  final String id;
  final String displayName;
  final Rarity rarity;
  final String? spriteUrl;
  final String? description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'rarity': rarity.wireValue,
        'sprite_url': spriteUrl,
        'description': description,
      };

  ProfessorSummary copyWith({
    String? id,
    String? displayName,
    Rarity? rarity,
    String? spriteUrl,
    String? description,
  }) =>
      ProfessorSummary(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        rarity: rarity ?? this.rarity,
        spriteUrl: spriteUrl ?? this.spriteUrl,
        description: description ?? this.description,
      );

  @override
  bool operator ==(Object other) => other is ProfessorSummary && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ProfessorSummary($id, $displayName)';
}
