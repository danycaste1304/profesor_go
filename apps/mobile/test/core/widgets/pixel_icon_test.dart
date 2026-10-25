import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/widgets/pixel_icon.dart';
import 'package:profesor_go/core/widgets/pixel_icons.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  RenderObject paintOf(WidgetTester tester) => tester.renderObject(
    find
        .descendant(
          of: find.byType(PixelIcon),
          matching: find.byType(CustomPaint),
        )
        .first,
  );

  testWidgets('draws at the glyph size with no extra room', (tester) async {
    await tester.pumpWidget(
      wrap(const PixelIcon(PixelIcons.alternateEmail, color: Colors.black)),
    );
    expect(tester.getSize(find.byType(PixelIcon)), const Size(24, 24));
    // First run of the glyph: row 1, columns 4-7, blocks of 2 px.
    expect(
      paintOf(tester),
      paints..rect(rect: const Rect.fromLTWH(8, 2, 8, 2)),
    );
  });

  testWidgets('is centered when a parent forces a bigger box', (tester) async {
    // InputDecoration gives a prefixIcon at least 48 x 48.
    await tester.pumpWidget(
      wrap(
        const TextField(
          decoration: InputDecoration(
            prefixIcon: PixelIcon(
              PixelIcons.alternateEmail,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PixelIcon)), const Size(48, 48));
    // The art is translated by (48 - 24) / 2 = 12 px each way, then drawn as
    // usual (the mock canvas records rects before the transform).
    expect(
      paintOf(tester),
      paints
        ..translate(x: 12, y: 12)
        ..rect(rect: const Rect.fromLTWH(8, 2, 8, 2)),
    );
  });
}
