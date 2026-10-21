import 'capture.dart';
import 'professor.dart';
import 'rarity.dart';

/// Result of `collection_progress()` RPC and the `collection` object in the
/// `resolve-capture` response (CONTRACTS §2/§4).
class CollectionProgress {
  const CollectionProgress({
    required this.captured,
    required this.total,
    required this.completed,
  });

  factory CollectionProgress.fromJson(Map<String, dynamic> json) =>
      CollectionProgress(
        captured: (json['captured'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        completed: json['completed'] as bool? ?? false,
      );

  static const empty = CollectionProgress(
    captured: 0,
    total: 0,
    completed: false,
  );

  final int captured;
  final int total;
  final bool completed;

  /// 0..1 fraction (0 when there are no professors).
  double get ratio => total == 0 ? 0 : (captured / total).clamp(0, 1);

  Map<String, dynamic> toJson() => {
        'captured': captured,
        'total': total,
        'completed': completed,
      };

  CollectionProgress copyWith({int? captured, int? total, bool? completed}) =>
      CollectionProgress(
        captured: captured ?? this.captured,
        total: total ?? this.total,
        completed: completed ?? this.completed,
      );

  /// Computes progress from the active professor list and the user's captures.
  static CollectionProgress compute({
    required List<Professor> professors,
    required List<Capture> captures,
  }) {
    final active = professors.where((p) => p.active).map((p) => p.id).toSet();
    final captured = captures
        .map((c) => c.professorId)
        .where(active.contains)
        .toSet()
        .length;
    return CollectionProgress(
      captured: captured,
      total: active.length,
      completed: active.isNotEmpty && captured >= active.length,
    );
  }

  /// Per-rarity breakdown (captured / total) for the active professors.
  /// Every rarity is present in the result, even with `total == 0`.
  static Map<Rarity, RarityProgress> byRarity({
    required List<Professor> professors,
    required List<Capture> captures,
  }) {
    final capturedIds = captures.map((c) => c.professorId).toSet();
    final result = <Rarity, RarityProgress>{};
    for (final rarity in Rarity.values) {
      final ofRarity = professors.where((p) => p.active && p.rarity == rarity);
      final total = ofRarity.length;
      final captured = ofRarity.where((p) => capturedIds.contains(p.id)).length;
      result[rarity] = RarityProgress(
        rarity: rarity,
        captured: captured,
        total: total,
      );
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is CollectionProgress &&
      other.captured == captured &&
      other.total == total &&
      other.completed == completed;

  @override
  int get hashCode => Object.hash(captured, total, completed);

  @override
  String toString() =>
      'CollectionProgress($captured/$total, completed=$completed)';
}

/// Captured / total for one rarity.
class RarityProgress {
  const RarityProgress({
    required this.rarity,
    required this.captured,
    required this.total,
  });

  final Rarity rarity;
  final int captured;
  final int total;

  bool get completed => total > 0 && captured >= total;
  double get ratio => total == 0 ? 0 : (captured / total).clamp(0, 1);

  @override
  bool operator ==(Object other) =>
      other is RarityProgress &&
      other.rarity == rarity &&
      other.captured == captured &&
      other.total == total;

  @override
  int get hashCode => Object.hash(rarity, captured, total);

  @override
  String toString() => 'RarityProgress(${rarity.wireValue} $captured/$total)';
}
