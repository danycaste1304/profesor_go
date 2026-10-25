import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/widgets/pixel_icons.dart';
import 'package:profesor_go/core/widgets/pixel_pill.dart';
import 'package:profesor_go/features/map/presentation/widgets/map_label.dart';

void main() {
  /// A 720 x 1290 "map" scaled by [scale], like the zoomed campus map.
  Widget map(MapLabel label, {double scale = 1}) => MaterialApp(
    theme: AppTheme.light(),
    home: Align(
      alignment: Alignment.topLeft,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 720,
          height: 1290,
          child: Stack(children: [label]),
        ),
      ),
    ),
  );

  MapLabel carpa({
    Offset position = const Offset(250, 600),
    bool draggable = false,
    ValueChanged<Offset>? onMoved,
  }) => MapLabel(
    id: 'carpa',
    position: position,
    label: 'Carpa',
    icon: PixelIcons.pin,
    color: AppColors.danger,
    draggable: draggable,
    onMoved: onMoved,
  );

  testWidgets('position is the bottom-center of the pill', (tester) async {
    await tester.pumpWidget(map(carpa()));
    final pill = find.byType(PixelPill);
    expect(tester.getBottomLeft(pill).dy, closeTo(600, 0.01));
    expect(tester.getCenter(pill).dx, closeTo(250, 0.01));
  });

  testWidgets('imageHeight enlarges the picture, not just its box', (
    tester,
  ) async {
    final image = MemoryImage(_onePixelPng);
    await tester.pumpWidget(
      map(
        MapLabel(
          id: 'x',
          position: const Offset(250, 600),
          label: 'X',
          icon: PixelIcons.pin,
          color: AppColors.danger,
          image: image,
          imageHeight: 100,
        ),
      ),
    );
    final widget = tester.widget<Image>(find.byType(Image));
    expect(tester.getSize(find.byType(Image)).height, 100);
    expect(widget.fit, BoxFit.contain);
  });

  testWidgets('an image-only label draws no pill', (tester) async {
    await tester.pumpWidget(
      map(
        MapLabel(
          id: 'carpa-x',
          semanticLabel: 'Carpa',
          position: const Offset(250, 600),
          image: MemoryImage(_onePixelPng),
          imageHeight: 100,
        ),
      ),
    );
    expect(find.byType(PixelPill), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Carpa',
      ),
      findsOneWidget,
    );
    // The base of the picture is the position, like the pill's base is.
    expect(tester.getBottomLeft(find.byType(Image)).dy, closeTo(600, 0.01));
  });

  testWidgets('is not draggable unless enabled', (tester) async {
    Offset? moved;
    await tester.pumpWidget(map(carpa(onMoved: (p) => moved = p)));
    await tester.drag(find.byType(PixelPill), const Offset(100, 0));
    await tester.pump();
    expect(moved, isNull);
    expect(tester.getCenter(find.byType(PixelPill)).dx, closeTo(250, 0.01));
  });

  testWidgets('drag reports map units, even on a zoomed map', (tester) async {
    final logs = <String>[];
    final previous = debugPrint;
    // Restored inside the test body: the framework checks debugPrint before
    // tear-downs run.
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');

    Offset? moved;
    await tester.pumpWidget(
      map(
        carpa(
          // Near the origin so the 2x map keeps it inside the test screen.
          position: const Offset(150, 250),
          draggable: true,
          onMoved: (p) => moved = p,
        ),
        scale: 2,
      ),
    );
    // 200 screen px on a 2x map are 100 map units.
    await tester.drag(
      find.byType(PixelPill),
      const Offset(200, -100),
      touchSlopX: 0,
      touchSlopY: 0,
    );
    await tester.pump();
    debugPrint = previous;

    expect(moved!.dx, closeTo(250, 0.5));
    expect(moved!.dy, closeTo(200, 0.5));
    expect(logs, contains('[MapLabel] carpa: Offset(250, 200)'));
  });
}

/// Smallest valid PNG (1 x 1 px), so the test needs no asset.
final _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
