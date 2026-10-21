import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/models.dart';

Capture _capture(String professorId) => Capture(
  id: 'cap-$professorId',
  userId: 'u',
  professorId: professorId,
  throwQuality: ThrowQuality.good,
  capturedAt: DateTime.utc(2026),
);

void main() {
  group('CollectionProgress', () {
    test('fromJson / toJson round-trip', () {
      const p = CollectionProgress(captured: 3, total: 8, completed: false);
      expect(CollectionProgress.fromJson(p.toJson()), p);
      expect(p.ratio, closeTo(0.375, 1e-9));
      expect(CollectionProgress.empty.ratio, 0);
    });

    test('compute counts only active professors and unique captures', () {
      final professors = [
        ...demoProfessors.take(3),
        demoProfessors[3].copyWith(active: false),
      ];
      final captures = [
        _capture(demoProfessors.first.id),
        _capture(demoProfessors.first.id).copyWith(id: 'dup'),
        _capture(demoProfessors[3].id), // inactive: ignored
      ];
      final p = CollectionProgress.compute(
        professors: professors,
        captures: captures,
      );
      expect(p.captured, 1);
      expect(p.total, 3);
      expect(p.completed, isFalse);
    });

    test('compute marks completed when everything active is captured', () {
      final p = CollectionProgress.compute(
        professors: demoProfessors,
        captures: [
          for (final professor in demoProfessors) _capture(professor.id),
        ],
      );
      expect(
        p,
        const CollectionProgress(captured: 10, total: 10, completed: true),
      );
    });

    test('byRarity computes captured/total for every rarity', () {
      final captures = [
        _capture(demoProfessors.first.id), // common
        _capture(demoProfessors[3].id), // Ricardo, rare
        _capture(demoProfessors[6].id), // Daniel, legendary
        _capture(demoProfessors[7].id), // Erick, legendary
      ];
      final byRarity = CollectionProgress.byRarity(
        professors: demoProfessors,
        captures: captures,
      );
      expect(byRarity.keys, containsAll(Rarity.values));
      expect(
        byRarity[Rarity.common],
        const RarityProgress(rarity: Rarity.common, captured: 1, total: 3),
      );
      expect(
        byRarity[Rarity.rare],
        const RarityProgress(rarity: Rarity.rare, captured: 1, total: 2),
      );
      expect(
        byRarity[Rarity.epic],
        const RarityProgress(rarity: Rarity.epic, captured: 0, total: 3),
      );
      expect(
        byRarity[Rarity.legendary],
        const RarityProgress(rarity: Rarity.legendary, captured: 2, total: 2),
      );
      expect(byRarity[Rarity.legendary]!.completed, isTrue);
      expect(byRarity[Rarity.epic]!.ratio, 0);
    });

    test('byRarity ignores inactive professors and unknown captures', () {
      final professors = [demoProfessors[7].copyWith(active: false)];
      final byRarity = CollectionProgress.byRarity(
        professors: professors,
        captures: [_capture(demoProfessors[7].id), _capture('ghost')],
      );
      expect(byRarity[Rarity.legendary]!.total, 0);
      expect(byRarity[Rarity.legendary]!.captured, 0);
    });
  });

  group('model json', () {
    test('Professor round-trips and falls back to rarity default rate', () {
      final p = demoProfessors.first;
      expect(Professor.fromJson(p.toJson()).toJson(), p.toJson());
      final noRate = Professor.fromJson({
        'id': 'x',
        'name': 'X',
        'display_name': 'Prof. X',
        'rarity': 'epic',
      });
      expect(noRate.baseCaptureRate, Rarity.epic.defaultCaptureRate);
      expect(noRate.active, isTrue);
    });

    test('Encounter parses the start-encounter response', () {
      final e = Encounter.fromJson({
        'encounter_id': 'enc-1',
        'expires_at': '2030-01-01T00:03:00Z',
        'professor': {
          'id': demoProfessorId(4),
          'display_name': 'Prof. Dijkstra',
          'rarity': 'RARE',
          'sprite_url': null,
          'description': null,
        },
      });
      expect(e.id, 'enc-1');
      expect(e.professor.rarity, Rarity.rare);
      expect(e.status, EncounterStatus.active);
      expect(e.isExpiredAt(DateTime.utc(2030, 1, 1, 0, 2)), isFalse);
      expect(e.isExpiredAt(DateTime.utc(2030, 1, 1, 0, 3)), isTrue);
      expect(
        e.remainingAt(DateTime.utc(2030, 1, 1, 0, 2)),
        const Duration(minutes: 1),
      );
      expect(e.remainingAt(DateTime.utc(2031)), Duration.zero);
    });

    test('CaptureResult parses both response shapes', () {
      final ok = CaptureResult.fromJson({
        'success': true,
        'professor_id': 'p1',
        'collection': {'captured': 8, 'total': 12, 'completed': false},
      });
      expect(ok.success, isTrue);
      expect(ok.collection?.captured, 8);
      expect(ok.retryRequiresNewNfcScan, isFalse);

      final ko = CaptureResult.fromJson({
        'success': false,
        'retry_requires_new_nfc_scan': true,
      });
      expect(ko.success, isFalse);
      expect(ko.collection, isNull);
      expect(ko.retryRequiresNewNfcScan, isTrue);
    });

    test('Profile parses role and nameOrEmail', () {
      final p = Profile.fromJson({
        'id': 'u',
        'email': 'ana@uni.edu',
        'role': 'ADMIN',
        'collection_completed_at': null,
      });
      expect(p.role, UserRole.admin);
      expect(p.nameOrEmail, 'ana');
      expect(p.copyWith(displayName: 'Ana').nameOrEmail, 'Ana');
      expect(p.hasCompletedCollection, isFalse);
    });
  });
}
