import '../mock/demo_game_state.dart';
import '../models/capture.dart';
import '../models/collection_progress.dart';
import '../models/professor.dart';
import 'professor_repository.dart';

/// In-memory [ProfessorRepository] over [DemoGameState].
class MockProfessorRepository implements ProfessorRepository {
  MockProfessorRepository(
    this.state, {
    ProfessorCache? cache,
    this.delay = const Duration(milliseconds: 150),
  }) : cache = cache ?? ProfessorCache(persistent: false);

  final DemoGameState state;
  final Duration delay;

  @override
  final ProfessorCache cache;

  Future<void> _simulateLatency() async {
    await state.ensureLoaded();
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<List<Professor>> getActiveProfessors() async {
    await _simulateLatency();
    final list = state.activeProfessors.toList()..sort(compareProfessors);
    await cache.saveProfessors(list);
    return list;
  }

  @override
  Future<List<Capture>> getMyCaptures() async {
    await _simulateLatency();
    final list = state.captures;
    await cache.saveCaptures(list);
    return list;
  }

  @override
  Future<CollectionProgress> getProgress() async {
    await _simulateLatency();
    final p = state.progress();
    await cache.saveProgress(p);
    return p;
  }
}
