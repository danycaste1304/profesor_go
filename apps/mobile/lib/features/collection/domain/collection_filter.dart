/// Pure helpers for the Profedex (collection) screens. No Flutter imports so
/// they can be unit-tested in isolation.
library;

import '../../../core/models/capture.dart';
import '../../../core/models/collection_progress.dart';
import '../../../core/models/professor.dart';
import '../../../core/models/rarity.dart';

/// Spanish label of a rarity filter (`null` = all rarities).
String rarityFilterLabel(Rarity? rarity) => rarity?.label ?? 'Todos';

/// Wire value of a rarity filter (`ALL` for `null`), used for keys / analytics.
String rarityFilterValue(Rarity? rarity) => rarity?.wireValue ?? 'ALL';

/// Keeps only the professors of [rarity]; `null` returns every professor.
/// Never returns inactive professors.
List<Professor> filterProfessors(List<Professor> professors, Rarity? rarity) {
  return professors
      .where((p) => p.active && (rarity == null || p.rarity == rarity))
      .toList(growable: false);
}

/// Stable ordering for the grid: rarest first (legendary → common), then
/// display name (case-insensitive), then id as a final tie-breaker so the
/// silhouettes never jump around between refreshes. Does not mutate [professors].
List<Professor> sortProfessors(List<Professor> professors) {
  final sorted = List<Professor>.of(professors)..sort(compareForCollection);
  return List.unmodifiable(sorted);
}

/// Comparator used by [sortProfessors].
int compareForCollection(Professor a, Professor b) {
  final byRank = b.rarity.rank.compareTo(a.rarity.rank);
  if (byRank != 0) return byRank;
  final byName = a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  if (byName != 0) return byName;
  return a.id.compareTo(b.id);
}

/// True when the player owns a capture of [professorId].
bool isCaptured(String professorId, List<Capture> captures) =>
    captures.any((c) => c.professorId == professorId);

/// The player's capture of [professorId], or `null` when not captured.
Capture? captureFor(String professorId, List<Capture> captures) {
  for (final c in captures) {
    if (c.professorId == professorId) return c;
  }
  return null;
}

/// `{captured, total, completed}` over the active professors only. Captures
/// of inactive / unknown professors are ignored, duplicates count once.
CollectionProgress progressFor(
  List<Professor> professors,
  List<Capture> captures,
) =>
    CollectionProgress.compute(professors: professors, captures: captures);

/// Per-rarity `captured / total` (every rarity present, inactive excluded).
Map<Rarity, RarityProgress> progressByRarity(
  List<Professor> professors,
  List<Capture> captures,
) =>
    CollectionProgress.byRarity(professors: professors, captures: captures);
