import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/capture.dart';
import '../../../core/models/collection_progress.dart';
import '../../../core/models/professor.dart';
import '../../../core/models/rarity.dart';
import '../domain/collection_filter.dart';

/// What the collection screens render: loading, an error (nothing to show,
/// not even cached data) or the data itself.
sealed class CollectionViewState {
  const CollectionViewState();
}

class CollectionLoading extends CollectionViewState {
  const CollectionLoading();
}

class CollectionError extends CollectionViewState {
  const CollectionError(this.error);

  final Object error;
}

class CollectionData extends CollectionViewState {
  CollectionData({
    required List<Professor> professors,
    required this.captures,
    required this.fromCache,
    this.refreshing = false,
  })  : professors = sortProfessors(professors),
        progress = progressFor(professors, captures),
        byRarity = progressByRarity(professors, captures);

  /// Active professors, already in the stable collection order.
  final List<Professor> professors;
  final List<Capture> captures;
  final CollectionProgress progress;
  final Map<Rarity, RarityProgress> byRarity;

  /// True when the data is the last known value (offline, request failed or
  /// still loading with a warm cache) rather than a fresh server response.
  final bool fromCache;

  /// True while a refresh is in flight (pull-to-refresh, invalidation).
  final bool refreshing;

  bool isCaptured(String professorId) => captureFor(professorId, captures) != null;

  Capture? captureOf(String professorId) => captureFor(professorId, captures);

  Professor? professorById(String id) {
    for (final p in professors) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Combines `professorsProvider` + `myCapturesProvider` with the repository
/// cache so the collection keeps working offline ("Mostrando datos guardados").
final collectionViewProvider = Provider<CollectionViewState>((ref) {
  final professorsAsync = ref.watch(professorsProvider);
  final capturesAsync = ref.watch(myCapturesProvider);
  final cache = ref.watch(professorRepositoryProvider).cache;
  final online = ref.watch(isOnlineProvider);

  final liveProfessors = professorsAsync.value;
  final liveCaptures = capturesAsync.value;
  final professors = liveProfessors ?? cache.professors;
  final captures = liveCaptures ?? cache.captures;

  if (professors == null || captures == null) {
    final error = professorsAsync.error ?? capturesAsync.error;
    if (error != null) return CollectionError(error);
    return const CollectionLoading();
  }

  final usedCache = liveProfessors == null || liveCaptures == null;
  return CollectionData(
    professors: professors,
    captures: captures,
    fromCache: usedCache ||
        !online ||
        professorsAsync.hasError ||
        capturesAsync.hasError,
    refreshing: professorsAsync.isLoading || capturesAsync.isLoading,
  );
});
