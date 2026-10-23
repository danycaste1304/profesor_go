import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/widgets/pixel_icon_button.dart';

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
          icon: Icons.music_note,
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
          icon: Icons.music_note,
          semanticLabel: 'Música',
          onPressed: null,
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PixelIconButton));
    expect(semantics.label, 'Música');
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('exposes the toggled state to accessibility', (tester) async {
    await tester.pumpWidget(
      wrap(
        PixelIconButton(
          icon: Icons.music_off,
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
