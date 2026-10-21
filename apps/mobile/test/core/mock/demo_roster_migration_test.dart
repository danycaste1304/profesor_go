import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/mock/demo_game_state.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/featured_professors.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final oldTuring = demoProfessors[1].copyWith(
    id: demoProfessorId(2),
    name: 'Alan Turing',
    displayName: 'Prof. Turing',
    rarity: Rarity.common,
    baseCaptureRate: 0.80,
  );
  final oldHopper = demoProfessors[2].copyWith(
    id: demoProfessorId(3),
    name: 'Grace Hopper',
    displayName: 'Prof. Hopper',
  );

  test(
    'real professors replace examples without inheriting their captures',
    () async {
      SharedPreferences.setMockInitialValues({});
      final then = DateTime.utc(2026, 10, 18, 12);
      final oldRoster = [
        demoProfessors.first,
        oldTuring,
        oldHopper,
        demoProfessors[3].copyWith(
          id: demoProfessorId(4),
          name: 'Edsger Dijkstra',
          displayName: 'Prof. Dijkstra',
        ),
        demoProfessors[4].copyWith(
          id: demoProfessorId(5),
          name: 'Barbara Liskov',
          displayName: 'Prof. Liskov',
          rarity: Rarity.rare,
          baseCaptureRate: 0.60,
        ),
        demoProfessors[5].copyWith(
          id: demoProfessorId(6),
          name: 'Donald Knuth',
          displayName: 'Prof. Knuth',
        ),
        demoProfessors[6].copyWith(id: demoProfessorId(7)),
        demoProfessors[7].copyWith(id: demoProfessorId(8)),
      ];
      final oldState = DemoGameState(
        professors: oldRoster,
        persist: true,
        clock: () => then,
      );
      await oldState.ensureLoaded();
      for (final professor in oldRoster) {
        await oldState.addCapture(
          Capture(
            id: 'capture-${professor.id}',
            userId: 'demo-user',
            professorId: professor.id,
            encounterId: 'encounter-${professor.id}',
            throwQuality: ThrowQuality.excellent,
            capturedAt: then,
          ),
        );
      }
      expect(oldState.progress().completed, isTrue);

      final updated = DemoGameState(persist: true);
      await updated.ensureLoaded();
      expect(
        updated.progress(),
        const CollectionProgress(captured: 1, total: 10, completed: false),
      );
      expect(updated.captures, hasLength(1));
      expect(updated.collectionCompletedAt, isNull);
      expect(updated.isCaptured(felipeGrijalvaId), isFalse);
      expect(updated.isCaptured(joseDavidVegaId), isFalse);
      expect(updated.isCaptured(ricardoFloresId), isFalse);
      expect(updated.isCaptured(pavelAlbaId), isFalse);
      expect(updated.isCaptured(noelPerezId), isFalse);
      expect(updated.isCaptured(danielRiofrioId), isFalse);
      expect(updated.isCaptured(erickNaunayId), isFalse);
      expect(
        updated.tagByIdentifier('DEMO-TAG-02')?.professorId,
        felipeGrijalvaId,
      );
      expect(
        updated.tagByIdentifier('DEMO-TAG-03')?.professorId,
        joseDavidVegaId,
      );
      expect(
        updated.tagByIdentifier('DEMO-TAG-04')?.professorId,
        ricardoFloresId,
      );
      expect(updated.tagByIdentifier('DEMO-TAG-05')?.professorId, pavelAlbaId);
      expect(updated.tagByIdentifier('DEMO-TAG-06')?.professorId, noelPerezId);
      expect(
        updated.tagByIdentifier('DEMO-TAG-07')?.professorId,
        danielRiofrioId,
      );
      expect(
        updated.tagByIdentifier('DEMO-TAG-08')?.professorId,
        erickNaunayId,
      );
    },
  );

  test(
    'Pavel and Ricardo replace old cards without inheriting their captures',
    () async {
      SharedPreferences.setMockInitialValues({});
      final then = DateTime.utc(2026, 10, 19, 9);
      final priorRoster = [
        demoProfessors.first,
        oldTuring,
        oldHopper,
        demoProfessors[3].copyWith(
          id: demoProfessorId(4),
          name: 'Edsger Dijkstra',
          displayName: 'Prof. Dijkstra',
        ),
        demoProfessors[4].copyWith(
          id: demoProfessorId(5),
          name: 'Barbara Liskov',
          displayName: 'Prof. Liskov',
          rarity: Rarity.rare,
          baseCaptureRate: 0.60,
        ),
        demoProfessors[5],
        demoProfessors[6],
        demoProfessors[7],
      ];
      final priorState = DemoGameState(
        professors: priorRoster,
        persist: true,
        clock: () => then,
      );
      await priorState.ensureLoaded();
      for (final professor in priorRoster) {
        await priorState.addCapture(
          Capture(
            id: 'capture-${professor.id}',
            userId: 'demo-user',
            professorId: professor.id,
            encounterId: 'encounter-${professor.id}',
            throwQuality: ThrowQuality.excellent,
            capturedAt: then,
          ),
        );
      }
      expect(priorState.progress().completed, isTrue);

      final updated = DemoGameState(persist: true);
      await updated.ensureLoaded();
      expect(
        updated.progress(),
        const CollectionProgress(captured: 4, total: 10, completed: false),
      );
      expect(updated.captures, hasLength(4));
      expect(updated.collectionCompletedAt, isNull);
      expect(updated.isCaptured(felipeGrijalvaId), isFalse);
      expect(updated.isCaptured(joseDavidVegaId), isFalse);
      expect(updated.isCaptured(ricardoFloresId), isFalse);
      expect(updated.isCaptured(noelPerezId), isTrue);
      expect(updated.isCaptured(pavelAlbaId), isFalse);
      expect(updated.isCaptured(danielRiofrioId), isTrue);
      expect(updated.isCaptured(erickNaunayId), isTrue);
      expect(updated.tagByIdentifier('DEMO-TAG-05')?.professorId, pavelAlbaId);
    },
  );

  test(
    'Ricardo replaces Dijkstra without inheriting the old capture',
    () async {
      SharedPreferences.setMockInitialValues({});
      final then = DateTime.utc(2026, 10, 19, 11);
      final priorRoster = [
        demoProfessors.first,
        oldTuring,
        oldHopper,
        demoProfessors[3].copyWith(
          id: demoProfessorId(4),
          name: 'Edsger Dijkstra',
          displayName: 'Prof. Dijkstra',
        ),
        ...demoProfessors.skip(4),
      ];
      final priorState = DemoGameState(
        professors: priorRoster,
        persist: true,
        clock: () => then,
      );
      await priorState.ensureLoaded();
      for (final professor in priorRoster) {
        await priorState.addCapture(
          Capture(
            id: 'capture-${professor.id}',
            userId: 'demo-user',
            professorId: professor.id,
            encounterId: 'encounter-${professor.id}',
            throwQuality: ThrowQuality.excellent,
            capturedAt: then,
          ),
        );
      }
      expect(priorState.progress().completed, isTrue);

      final updated = DemoGameState(persist: true);
      await updated.ensureLoaded();
      expect(
        updated.progress(),
        const CollectionProgress(captured: 7, total: 10, completed: false),
      );
      expect(updated.captures, hasLength(7));
      expect(updated.collectionCompletedAt, isNull);
      expect(updated.isCaptured(felipeGrijalvaId), isFalse);
      expect(updated.isCaptured(joseDavidVegaId), isFalse);
      expect(updated.isCaptured(ricardoFloresId), isFalse);
      expect(updated.isCaptured(pavelAlbaId), isTrue);
      expect(updated.isCaptured(noelPerezId), isTrue);
      expect(
        updated.tagByIdentifier('DEMO-TAG-04')?.professorId,
        ricardoFloresId,
      );
    },
  );

  test(
    'Jose David replaces Hopper without inheriting the old capture',
    () async {
      SharedPreferences.setMockInitialValues({});
      final then = DateTime.utc(2026, 10, 19, 12);
      final priorRoster = [
        demoProfessors.first,
        oldTuring,
        oldHopper,
        ...demoProfessors.skip(3),
      ];
      final priorState = DemoGameState(
        professors: priorRoster,
        persist: true,
        clock: () => then,
      );
      await priorState.ensureLoaded();
      for (final professor in priorRoster) {
        await priorState.addCapture(
          Capture(
            id: 'capture-${professor.id}',
            userId: 'demo-user',
            professorId: professor.id,
            encounterId: 'encounter-${professor.id}',
            throwQuality: ThrowQuality.excellent,
            capturedAt: then,
          ),
        );
      }
      expect(priorState.progress().completed, isTrue);

      final updated = DemoGameState(persist: true);
      await updated.ensureLoaded();
      expect(
        updated.progress(),
        const CollectionProgress(captured: 8, total: 10, completed: false),
      );
      expect(updated.captures, hasLength(8));
      expect(updated.collectionCompletedAt, isNull);
      expect(updated.isCaptured(felipeGrijalvaId), isFalse);
      expect(updated.isCaptured(joseDavidVegaId), isFalse);
      expect(updated.isCaptured(ricardoFloresId), isTrue);
      expect(
        updated.tagByIdentifier('DEMO-TAG-03')?.professorId,
        joseDavidVegaId,
      );
    },
  );

  test('Felipe replaces Turing without inheriting the old capture', () async {
    SharedPreferences.setMockInitialValues({});
    final then = DateTime.utc(2026, 10, 19, 13);
    final priorRoster = [
      demoProfessors.first,
      oldTuring,
      ...demoProfessors.skip(2),
    ];
    final priorState = DemoGameState(
      professors: priorRoster,
      persist: true,
      clock: () => then,
    );
    await priorState.ensureLoaded();
    for (final professor in priorRoster) {
      await priorState.addCapture(
        Capture(
          id: 'capture-${professor.id}',
          userId: 'demo-user',
          professorId: professor.id,
          encounterId: 'encounter-${professor.id}',
          throwQuality: ThrowQuality.excellent,
          capturedAt: then,
        ),
      );
    }
    expect(priorState.progress().completed, isTrue);

    final updated = DemoGameState(persist: true);
    await updated.ensureLoaded();
    expect(
      updated.progress(),
      const CollectionProgress(captured: 9, total: 10, completed: false),
    );
    expect(updated.captures, hasLength(9));
    expect(updated.collectionCompletedAt, isNull);
    expect(updated.isCaptured(felipeGrijalvaId), isFalse);
    expect(updated.isCaptured(joseDavidVegaId), isTrue);
    expect(
      updated.tagByIdentifier('DEMO-TAG-02')?.professorId,
      felipeGrijalvaId,
    );
  });

  test('Henry replaces Ada without inheriting her capture', () async {
    SharedPreferences.setMockInitialValues({});
    final then = DateTime.utc(2026, 10, 19, 15);
    final oldAda = demoProfessors.first.copyWith(
      id: demoProfessorId(1),
      name: 'Ada Lovelace',
      displayName: 'Prof. Ada',
    );
    final priorRoster = [oldAda, ...demoProfessors.skip(1)];
    final priorState = DemoGameState(
      professors: priorRoster,
      persist: true,
      clock: () => then,
    );
    await priorState.ensureLoaded();
    for (final professor in priorRoster) {
      await priorState.addCapture(
        Capture(
          id: 'capture-${professor.id}',
          userId: 'demo-user',
          professorId: professor.id,
          encounterId: 'encounter-${professor.id}',
          throwQuality: ThrowQuality.excellent,
          capturedAt: then,
        ),
      );
    }
    expect(priorState.progress().completed, isTrue);

    final updated = DemoGameState(persist: true);
    await updated.ensureLoaded();
    expect(
      updated.progress(),
      const CollectionProgress(captured: 9, total: 10, completed: false),
    );
    expect(updated.captures, hasLength(9));
    expect(updated.collectionCompletedAt, isNull);
    expect(updated.isCaptured(henryCarvajalId), isFalse);
    expect(updated.isCaptured(robertoAndradeId), isTrue);
    expect(
      updated.tagByIdentifier('DEMO-TAG-01')?.professorId,
      henryCarvajalId,
    );
    expect(updated.tagByIdentifier('DEMO-TAG-09')?.professorId, diegoMoralesId);
    expect(
      updated.tagByIdentifier('DEMO-TAG-10')?.professorId,
      robertoAndradeId,
    );
  });
}
