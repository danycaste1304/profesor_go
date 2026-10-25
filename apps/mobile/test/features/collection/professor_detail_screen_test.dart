import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/widgets/widgets.dart';
import 'package:profesor_go/features/collection/domain/date_format.dart';
import 'package:profesor_go/features/collection/presentation/professor_detail_screen.dart';

import 'fakes.dart';

void main() {
  final capturedAt = DateTime.utc(2026, 9, 16, 10, 30);

  Future<void> pumpDetail(
    WidgetTester tester,
    FakeProfessorRepository repo,
    String professorId,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      buildCollectionApp(
        repository: repo,
        initialLocation: '/collection/$professorId',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('captured professor shows name, description and capture data', (
    tester,
  ) async {
    final ada = demoProfessors[0];
    final repo = FakeProfessorRepository(
      captures: [
        captureOf(ada.id, at: capturedAt, quality: ThrowQuality.excellent),
      ],
    );
    await pumpDetail(tester, repo, ada.id);

    expect(find.byType(ProfessorDetailScreen), findsOneWidget);
    expect(find.text('Prof. Henry'), findsOneWidget); // body
    expect(find.text('PROFESOR'), findsOneWidget); // app bar, same for everyone
    expect(find.text('Henry Carvajal'), findsOneWidget);
    expect(find.text(ada.description!), findsOneWidget);
    expect(find.text(ProfessorDetailScreen.undiscoveredHint), findsNothing);
    expect(find.text('???'), findsNothing);
    expect(find.text(formatDateTime(capturedAt)), findsOneWidget);
    expect(find.text('Excelente'), findsOneWidget);
    expect(find.text('80 %'), findsOneWidget);

    final sprite = tester.widget<ProfessorSprite>(find.byType(ProfessorSprite));
    expect(sprite.silhouette, isFalse);
    expect(find.byType(RarityBadge), findsOneWidget);
  });

  testWidgets('uncaptured professor hides name and description', (
    tester,
  ) async {
    final noel = demoProfessors[5];
    final repo = FakeProfessorRepository(captures: const []);
    await pumpDetail(tester, repo, noel.id);

    expect(find.text('???'), findsWidgets);
    expect(find.text('PROFESOR'), findsOneWidget);
    expect(find.text('Prof. Noel'), findsNothing);
    expect(find.text('Noel Pérez'), findsNothing);
    expect(find.text(noel.description!), findsNothing);
    expect(find.text(ProfessorDetailScreen.undiscoveredHint), findsOneWidget);
    expect(find.textContaining('Capturado el'), findsNothing);
    expect(
      find.text('Épica'),
      findsOneWidget,
    ); // stat row label (badge is upper-case)

    final sprite = tester.widget<ProfessorSprite>(find.byType(ProfessorSprite));
    expect(sprite.silhouette, isTrue);
  });

  testWidgets('unknown professor id shows a friendly error', (tester) async {
    final repo = FakeProfessorRepository();
    await pumpDetail(tester, repo, 'does-not-exist');

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('No encontramos a este profesor.'), findsOneWidget);
    expect(find.byType(ProfessorSprite), findsNothing);
  });

  testWidgets('lays out at phone width without overflow', (tester) async {
    final pavel = demoProfessors[4];
    final repo = FakeProfessorRepository(captures: [captureOf(pavel.id)]);
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      buildCollectionApp(
        repository: repo,
        initialLocation: '/collection/${pavel.id}',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1500),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Genial'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
