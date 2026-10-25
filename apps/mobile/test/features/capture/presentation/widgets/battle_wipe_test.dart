import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/features/capture/presentation/widgets/battle_wipe.dart';

void main() {
  const n = BattleWipe.barCount;

  test('covering goes from empty to full, bar by bar', () {
    for (var i = 0; i < n; i++) {
      expect(BattleWipePainter.barCoverage(i, 0), 0);
      expect(BattleWipePainter.barCoverage(i, 1), 1);
    }
    // Staggered: halfway through, the first bar is ahead of the last one.
    expect(
      BattleWipePainter.barCoverage(0, 0.5),
      greaterThan(BattleWipePainter.barCoverage(n - 1, 0.5)),
    );
  });

  test('revealing goes from full back to empty', () {
    for (var i = 0; i < n; i++) {
      expect(BattleWipePainter.barCoverage(i, 0, revealing: true), 1);
      expect(BattleWipePainter.barCoverage(i, 1, revealing: true), 0);
    }
  });

  testWidgets('a full cover paints every bar edge to edge', (tester) async {
    await tester.pumpWidget(
      const Center(
        child: SizedBox(
          width: 400,
          height: 600,
          child: CustomPaint(painter: BattleWipePainter(progress: 1)),
        ),
      ),
    );
    final box = tester.renderObject(find.byType(CustomPaint).last);
    // Bar 0 comes from the left, bar 1 from the right; both span the width.
    expect(
      box,
      paints
        ..rect(rect: const Rect.fromLTRB(0, 0, 400, 60))
        ..rect(rect: const Rect.fromLTRB(0, 60, 400, 120)),
    );
  });

  testWidgets('play covers, navigates once, reveals and cleans up', (
    tester,
  ) async {
    var covered = 0;
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                await BattleWipe.play(context, onCovered: () => covered++);
                finished = true;
              },
              child: const Text('GO'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pump();
    await tester.pump(BattleWipe.cover ~/ 2);
    expect(covered, 0);
    await tester.pump(BattleWipe.cover);
    expect(covered, 1);
    await tester.pump(BattleWipe.hold + BattleWipe.reveal);
    await tester.pump();
    expect(covered, 1);
    expect(finished, isTrue);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BattleWipePainter,
      ),
      findsNothing,
    );
  });
}
