import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/featured_professors.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/features/collection/domain/collection_filter.dart';
import 'package:profesor_go/features/collection/domain/date_format.dart';

import 'fakes.dart';

void main() {
  group('filterProfessors', () {
    test('null keeps every active professor', () {
      expect(filterProfessors(demoProfessors, null).length, 10);
    });

    test('narrows to one rarity', () {
      final rare = filterProfessors(demoProfessors, Rarity.rare);
      expect(rare.map((p) => p.displayName), ['Prof. Ricardo', 'Prof. Diego']);
      expect(filterProfessors(demoProfessors, Rarity.common).length, 3);
      expect(filterProfessors(demoProfessors, Rarity.epic).length, 3);
      expect(filterProfessors(demoProfessors, Rarity.legendary).length, 2);
    });

    test('never returns inactive professors', () {
      final list = [
        demoProfessors[0].copyWith(active: false),
        demoProfessors[1],
      ];
      expect(filterProfessors(list, null).map((p) => p.id), [felipeGrijalvaId]);
      expect(filterProfessors(list, Rarity.epic).length, 1);
    });
  });

  group('sortProfessors', () {
    test('orders rarest first, then display name, and is stable', () {
      final shuffled = List<Professor>.of(demoProfessors)..shuffle();
      final sorted = sortProfessors(shuffled);
      expect(sorted.map((p) => p.displayName), [
        'Prof. Daniel',
        'Prof. Erick',
        'Prof. Felipe',
        'Prof. Noel',
        'Prof. Pavel',
        'Prof. Diego',
        'Prof. Ricardo',
        'Prof. Henry',
        'Prof. José David',
        'Prof. Roberto',
      ]);
      expect(sortProfessors(sorted), sorted);
      expect(sortProfessors(sorted.reversed.toList()), sorted);
    });

    test('does not mutate the input and breaks ties by id', () {
      final a = demoProfessors[0].copyWith(id: 'b', displayName: 'Prof. Same');
      final b = demoProfessors[1].copyWith(id: 'a', displayName: 'prof. same');
      final input = [a, b];
      final sorted = sortProfessors(input);
      expect(sorted.map((p) => p.id), ['a', 'b']);
      expect(input.map((p) => p.id), ['b', 'a']);
      expect(() => sorted.add(a), throwsUnsupportedError);
    });
  });

  group('isCaptured / captureFor', () {
    final captures = [
      captureOf(demoProfessors.first.id),
      captureOf(demoProfessors[7].id),
    ];

    test('finds captures by professor id', () {
      expect(isCaptured(demoProfessors.first.id, captures), isTrue);
      expect(isCaptured(demoProfessors[7].id, captures), isTrue);
      expect(isCaptured(demoProfessors[1].id, captures), isFalse);
      expect(isCaptured('ghost', const []), isFalse);
      expect(
        captureFor(demoProfessors[7].id, captures)?.id,
        'cap-${demoProfessors[7].id}',
      );
      expect(captureFor(demoProfessors[2].id, captures), isNull);
    });
  });

  group('progressFor', () {
    test('counts captured / total and completed', () {
      final captures = [
        captureOf(demoProfessors.first.id),
        captureOf(demoProfessors[3].id),
        captureOf(demoProfessors[7].id),
      ];
      final p = progressFor(demoProfessors, captures);
      expect(
        p,
        const CollectionProgress(captured: 3, total: 10, completed: false),
      );
      expect(p.ratio, closeTo(0.3, 1e-9));
    });

    test('excludes inactive professors and their captures', () {
      final professors = [
        ...demoProfessors.take(2),
        demoProfessors[2].copyWith(active: false),
      ];
      final captures = [
        captureOf(demoProfessors.first.id),
        captureOf(demoProfessors[2].id), // inactive: ignored
        captureOf('unknown'),
      ];
      expect(
        progressFor(professors, captures),
        const CollectionProgress(captured: 1, total: 2, completed: false),
      );
    });

    test('is completed when every active professor is captured', () {
      final captures = [for (final p in demoProfessors) captureOf(p.id)];
      final p = progressFor(demoProfessors, captures);
      expect(p.completed, isTrue);
      expect(p.captured, 10);
      expect(progressFor(const [], captures).completed, isFalse);
    });
  });

  group('progressByRarity', () {
    test('breaks the progress down per rarity', () {
      final captures = [
        captureOf(demoProfessors.first.id),
        captureOf(demoProfessors[3].id),
        captureOf(demoProfessors[6].id),
        captureOf(demoProfessors[7].id),
      ];
      final by = progressByRarity(demoProfessors, captures);
      expect(by.keys, containsAll(Rarity.values));
      expect(by[Rarity.common]!.captured, 1);
      expect(by[Rarity.common]!.total, 3);
      expect(by[Rarity.rare]!.captured, 1);
      expect(by[Rarity.rare]!.total, 2);
      expect(by[Rarity.epic]!.captured, 0);
      expect(by[Rarity.epic]!.total, 3);
      expect(by[Rarity.legendary]!.total, 2);
      expect(by[Rarity.legendary]!.completed, isTrue);
    });

    test('ignores inactive professors', () {
      final professors = [demoProfessors[7].copyWith(active: false)];
      final by = progressByRarity(professors, [
        captureOf(demoProfessors[7].id),
      ]);
      expect(by[Rarity.legendary]!.total, 0);
      expect(by[Rarity.legendary]!.captured, 0);
    });
  });

  group('labels', () {
    test('rarityFilterLabel / rarityFilterValue', () {
      expect(rarityFilterLabel(null), 'Todos');
      expect(rarityFilterLabel(Rarity.epic), 'Épica');
      expect(rarityFilterValue(null), 'ALL');
      expect(rarityFilterValue(Rarity.legendary), 'LEGENDARY');
    });
  });

  group('date format', () {
    test('zero-pads day, month, hour and minute', () {
      final local = DateTime(2026, 3, 5, 7, 4);
      expect(formatDate(local), '05/03/2026');
      expect(formatDateTime(local), '05/03/2026 07:04');
    });
  });
}
