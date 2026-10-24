import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/widgets/pixel_button.dart';

void main() {
  test('each variant carries its own colors', () {
    expect(
      PixelButtonVariant.primary.style.face,
      const Color.fromARGB(255, 213, 53, 71),
    );
    expect(PixelButtonVariant.primary.style.foreground, AppColors.surface);
    expect(
      PixelButtonVariant.secondary.style.face,
      const Color.fromARGB(255, 209, 232, 243),
    );
    expect(PixelButtonVariant.secondary.style.foreground, AppColors.text);
    expect(PixelButtonVariant.neutral.style.face, AppColors.surface);
    expect(PixelButtonVariant.neutral.style.foreground, AppColors.text);
    expect(PixelButtonVariant.tertiary.style.face, AppColors.accent);
    expect(PixelButtonVariant.danger.style.face, AppColors.dangerFill);
    for (final variant in PixelButtonVariant.values) {
      expect(variant.style.outline, isNot(variant.style.face));
    }
  });

  testWidgets('named constructors pick the variant; default is tertiary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              PixelButton(label: 'Default', onPressed: () {}),
              PixelButton.primary(label: 'Primary', onPressed: () {}),
              PixelButton.secondary(label: 'Secondary', onPressed: () {}),
              PixelButton.neutral(label: 'Neutral', onPressed: () {}),
              PixelButton.danger(label: 'Danger', onPressed: () {}),
            ],
          ),
        ),
      ),
    );
    final variants = tester
        .widgetList<PixelButton>(find.byType(PixelButton))
        .map((b) => b.variant)
        .toList();
    expect(variants, [
      PixelButtonVariant.tertiary,
      PixelButtonVariant.primary,
      PixelButtonVariant.secondary,
      PixelButtonVariant.neutral,
      PixelButtonVariant.danger,
    ]);
  });
}
