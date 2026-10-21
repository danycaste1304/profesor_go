import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/widgets/widgets.dart';
import 'package:profesor_go/features/collection/presentation/collection_widgets.dart';
import 'package:profesor_go/features/collection/presentation/professor_detail_screen.dart';

import 'fakes.dart';

void main() {
  late FakeProfessorRepository repo;

  /// Henry (common), Ricardo (rare) and Erick (legendary) captured.
  final threeCaptures = [
    captureOf(demoProfessors.first.id),
    captureOf(demoProfessors[3].id),
    captureOf(demoProfessors[7].id),
  ];

  setUp(() {
    repo = FakeProfessorRepository(captures: threeCaptures);
  });

  Future<void> pumpCollection(
    WidgetTester tester, {
    bool online = true,
    FakeAuthRepository? auth,
  }) async {
    // Tall surface so the whole grid is laid out (slivers build lazily).
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      buildCollectionApp(repository: repo, online: online, auth: auth),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  int silhouetteCount(WidgetTester tester) => tester
      .widgetList<ProfessorSprite>(find.byType(ProfessorSprite))
      .where((s) => s.silhouette)
      .length;

  testWidgets('shows 10 professors: 3 captured with names, 7 silhouettes', (
    tester,
  ) async {
    await pumpCollection(tester);

    expect(find.text('COLECCIÓN'), findsOneWidget);
    expect(find.byType(ProfessorSprite), findsNWidgets(10));
    expect(silhouetteCount(tester), 7);
    expect(find.text('???'), findsWidgets);
    expect(find.text('Prof. Henry'), findsOneWidget);
    expect(find.text('Prof. Ricardo'), findsOneWidget);
    expect(find.text('Prof. Erick'), findsOneWidget);
    expect(find.text('Prof. Noel'), findsNothing);
    expect(find.text('3 / 10'), findsOneWidget);
    expect(find.byType(RarityBadge), findsNWidgets(10));
    expect(find.byType(CachedDataBanner), findsNothing);

    // Stable order: rarest first, so the legendary card comes before the common.
    final erick = tester.getTopLeft(
      find.byKey(Key('professor-${demoProfessors[7].id}')),
    );
    final ada = tester.getTopLeft(
      find.byKey(Key('professor-${demoProfessors.first.id}')),
    );
    expect(erick.dy <= ada.dy, isTrue);
  });

  testWidgets('RARE chip narrows the grid, ALL restores it', (tester) async {
    await pumpCollection(tester);

    await tester.tap(find.byKey(const Key('filter-RARE')));
    await tester.pump();
    expect(find.byType(ProfessorSprite), findsNWidgets(2));
    expect(find.text('Prof. Ricardo'), findsOneWidget);
    expect(find.text('???'), findsWidgets); // Diego is still a silhouette.
    expect(find.text('3 / 10'), findsOneWidget); // header is global

    await tester.tap(find.byKey(const Key('filter-ALL')));
    await tester.pump();
    expect(find.byType(ProfessorSprite), findsNWidgets(10));
  });

  testWidgets('tapping a card opens the professor detail', (tester) async {
    await pumpCollection(tester);

    await tester.tap(find.byKey(Key('professor-${demoProfessors.first.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ProfessorDetailScreen), findsOneWidget);
    expect(find.text(demoProfessors[0].description!), findsOneWidget);
  });

  testWidgets('error without cache shows ErrorView and retry reloads', (
    tester,
  ) async {
    repo.professorsError = AppException.fromCode(
      AppException.serverUnavailable,
    );
    await pumpCollection(tester);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(
      find.text(AppException.messages[AppException.serverUnavailable]!),
      findsOneWidget,
    );
    expect(find.byType(ProfessorSprite), findsNothing);

    repo.professorsError = null;
    await tester.tap(find.text('REINTENTAR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ProfessorSprite), findsNWidgets(10));
    expect(repo.professorCalls, 2);
  });

  testWidgets('error with a warm cache shows cached data + banner', (
    tester,
  ) async {
    await repo.cache.saveProfessors(demoProfessors);
    await repo.cache.saveCaptures(threeCaptures);
    repo.professorsError = AppException.fromCode(AppException.noInternet);
    repo.capturesError = AppException.fromCode(AppException.noInternet);
    await pumpCollection(tester);

    expect(find.byType(ErrorView), findsNothing);
    expect(find.byType(ProfessorSprite), findsNWidgets(10));
    expect(find.text('3 / 10'), findsOneWidget);
    expect(find.text(CachedDataBanner.text), findsOneWidget);
  });

  testWidgets('offline shows the cached-data banner', (tester) async {
    await pumpCollection(tester, online: false);
    expect(find.text(CachedDataBanner.text), findsOneWidget);
    expect(find.byType(ProfessorSprite), findsNWidgets(10));
  });

  testWidgets('empty professor list shows an empty state', (tester) async {
    repo.professors = const [];
    repo.captures = const [];
    await pumpCollection(tester);
    expect(find.byType(ProfessorSprite), findsNothing);
    expect(find.textContaining('Aún no hay profesores'), findsOneWidget);
    expect(find.text('0 / 0'), findsOneWidget);
  });

  testWidgets('completed collection shows the achievement shortcut', (
    tester,
  ) async {
    repo.captures = [for (final p in demoProfessors) captureOf(p.id)];
    await pumpCollection(tester);
    expect(find.text('10 / 10'), findsOneWidget);
    expect(find.text('???'), findsNothing);
    expect(find.text('¡Colección completa!'), findsOneWidget);
    expect(find.text('VER LOGRO'), findsOneWidget);
  });

  testWidgets(
    'lays out at phone width without overflow (2 columns, long names)',
    (tester) async {
      repo.professors = [
        demoProfessors[0].copyWith(
          displayName: 'Prof. Margarita Hamiltonia de las Mercedes',
        ),
        ...demoProfessors.skip(1),
      ];
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildCollectionApp(repository: repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Two columns: the first two cards share a row.
      final first = tester.getTopLeft(
        find.byKey(Key('professor-${demoProfessors[6].id}')),
      );
      final second = tester.getTopLeft(
        find.byKey(Key('professor-${demoProfessors[7].id}')),
      );
      expect(first.dy, second.dy);
      expect(first.dx < second.dx, isTrue);

      // Scroll to the bottom so every card (incl. the long name) is laid out.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.textContaining('Margarita'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rarity filters keep a 48 dp target and scroll at 320 dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildCollectionApp(repository: repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final chips = find.byType(RarityFilterChip);
    expect(chips, findsNWidgets(5)); // Todos + 4 rarities
    for (var i = 0; i < 5; i++) {
      final size = tester.getSize(chips.at(i));
      expect(size.height, greaterThanOrEqualTo(48.0), reason: 'chip $i height');
      expect(size.width, greaterThanOrEqualTo(48.0), reason: 'chip $i width');
    }

    // The row does not shrink the targets: it scrolls horizontally instead.
    final row = find.ancestor(
      of: chips.first,
      matching: find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      ),
    );
    expect(row, findsOneWidget);
    final beforeDrag = tester.getTopLeft(chips.last).dx;
    await tester.drag(row, const Offset(-200, 0));
    await tester.pump();
    expect(tester.getTopLeft(chips.last).dx, lessThan(beforeDrag));

    // The last filter is reachable and still usable after scrolling.
    await tester.ensureVisible(chips.last);
    await tester.pump();
    await tester.tap(chips.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Prof. Erick'), findsOneWidget);
    expect(silhouetteCount(tester), 1); // Daniel is still undiscovered.
    expect(find.text('Prof. Henry'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
