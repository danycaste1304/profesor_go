import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/widgets/pixel_bar_painter.dart';
import 'package:profesor_go/core/widgets/progress_bar.dart';

void main() {
  Widget wrap(ProgressBar bar) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: bar),
  );

  testWidgets('shows only the percentage by default', (tester) async {
    await tester.pumpWidget(
      wrap(const ProgressBar(value: 3, total: 10, label: 'Capturados')),
    );
    expect(find.text('30 %'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('rounds the percentage', (tester) async {
    await tester.pumpWidget(
      wrap(const ProgressBar(value: 1, total: 3, label: 'Capturados')),
    );
    expect(find.text('33 %'), findsOneWidget);
  });

  testWidgets('the count is opt-in and goes next to the percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ProgressBar(
          value: 3,
          total: 10,
          label: 'Capturados',
          showCount: true,
        ),
      ),
    );
    expect(find.text('3 / 10 · 30 %'), findsOneWidget);
  });

  testWidgets('can hide the header text for slim bars', (tester) async {
    await tester.pumpWidget(
      wrap(const ProgressBar(value: 5, total: 10, showPercent: false)),
    );
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('draws the pixel bar and animates to the final ratio', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ProgressBar(value: 5, total: 10, label: 'Capturados')),
    );
    await tester.pumpAndSettle();

    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(ProgressBar),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as PixelBarPainter;
    expect(painter.ratio, 0.5);
  });

  testWidgets('the percentage is flush with the right edge of the bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ProgressBar(value: 3, total: 10, label: 'Capturados')),
    );

    final bar = tester.getTopRight(find.byType(ProgressBar)).dx;
    final percent = tester.getTopRight(find.text('30 %')).dx;
    expect(percent, closeTo(bar, 0.01));
  });
}
