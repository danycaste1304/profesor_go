import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/widgets/pixel_icon.dart';
import 'package:profesor_go/core/widgets/pixel_icons.dart';
import 'package:profesor_go/core/widgets/pixel_pill.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('shows the icon before the label when given', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PixelPill(
          label: 'Poli',
          icon: PixelIcons.pin,
          color: AppColors.danger,
        ),
      ),
    );
    expect(find.byType(PixelIcon), findsOneWidget);
    expect(find.text('POLI'), findsOneWidget);
  });

  testWidgets('scale multiplies the pill size', (tester) async {
    Future<Size> sizeAt(double scale) async {
      await tester.pumpWidget(
        wrap(
          PixelPill(
            label: 'Poli',
            icon: PixelIcons.pin,
            color: AppColors.danger,
            scale: scale,
          ),
        ),
      );
      return tester.getSize(find.byType(PixelPill));
    }

    final normal = await sizeAt(1);
    final double2 = await sizeAt(2);
    expect(double2.height, closeTo(normal.height * 2, 1));
    expect(double2.width, closeTo(normal.width * 2, 4));
  });

  testWidgets('is text-only without an icon', (tester) async {
    await tester.pumpWidget(
      wrap(const PixelPill(label: 'Poli', color: AppColors.danger)),
    );
    expect(find.byType(PixelIcon), findsNothing);
    expect(find.text('POLI'), findsOneWidget);
  });
}
