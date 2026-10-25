import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/widgets/pixel_button.dart';
import 'package:profesor_go/core/widgets/pixel_circle_painter.dart';
import 'package:profesor_go/core/widgets/pixel_icon_button.dart';
import 'package:profesor_go/core/widgets/pixel_icons.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('calls onPressed and keeps the 48 px touch target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        PixelIconButton(
          icon: PixelIcons.musicNote,
          semanticLabel: 'Música',
          onPressed: () => taps++,
        ),
      ),
    );

    expect(tester.getSize(find.byType(PixelIconButton)), const Size(48, 48));
    await tester.tap(find.byType(PixelIconButton));
    expect(taps, 1);
  });

  testWidgets('is inert when onPressed is null', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PixelIconButton(
          icon: PixelIcons.musicNote,
          semanticLabel: 'Música',
          onPressed: null,
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PixelIconButton));
    expect(semantics.label, 'Música');
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('toggled face follows the tertiary button variant', (
    tester,
  ) async {
    Color faceOf(WidgetTester tester) {
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(PixelIconButton),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is PixelCirclePainter,
          ),
        ),
      );
      return (paint.painter! as PixelCirclePainter).face;
    }

    for (final toggled in [true, false]) {
      await tester.pumpWidget(
        wrap(
          PixelIconButton(
            icon: PixelIcons.walk,
            semanticLabel: 'Simular',
            toggled: toggled,
            onPressed: () {},
          ),
        ),
      );
      expect(
        faceOf(tester),
        toggled ? PixelButtonVariant.tertiary.style.face : AppColors.surface,
      );
    }
  });

  testWidgets('exposes the toggled state to accessibility', (tester) async {
    await tester.pumpWidget(
      wrap(
        PixelIconButton(
          icon: PixelIcons.musicOff,
          semanticLabel: 'Música',
          toggled: true,
          onPressed: () {},
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PixelIconButton));
    expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
  });
}
