import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/widgets/pixel_icon_button.dart';
import 'package:profesor_go/features/avatar/avatar_style.dart';
import 'package:profesor_go/features/map/domain/campus_map_config.dart';
import 'package:profesor_go/features/map/presentation/widgets/avatar.dart';
import 'package:profesor_go/features/map/presentation/widgets/campus_map.dart';
import 'package:profesor_go/features/map/presentation/widgets/fair_map_labels.dart';
import 'package:profesor_go/features/map/presentation/widgets/map_label.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: SizedBox.expand(child: child)),
  );

  Widget wrapViewport(Widget child) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, height: 500, child: child)),
    ),
  );

  Offset cameraPosition(WidgetTester tester, Offset mapPosition) {
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    return MatrixUtils.transformPoint(
      viewer.transformationController!.value,
      mapPosition,
    );
  }

  Positioned avatarPositioned(WidgetTester tester) => tester.widget<Positioned>(
    find.descendant(
      of: find.byKey(CampusMap.avatarKey),
      matching: find.byType(Positioned),
    ),
  );

  testWidgets('shows the bundled pixel map and no avatar without a position', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const CampusMap(avatarOffset: null)));
    // The map itself plus the tent picture of the POLI label.
    expect(find.byType(Image), findsNWidgets(7));
    expect(find.byType(MapLabel), findsNWidgets(FairMapLabels.all.length));
    expect(find.text('POLI'), findsOneWidget);
    // POLI's tent plus the five picture-only ones.
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(PixelAvatar), findsNothing);
  });

  test('every fair label is fixed once its position is final', () {
    // To move one again, give it `draggable: MapLabel.dragEnabled`.
    expect(FairMapLabels.all.where((l) => l.draggable), isEmpty);
  });

  testWidgets('uses Image.asset when a background asset path is configured', (
    tester,
  ) async {
    const config = CampusMapConfig(backgroundAssetPath: 'assets/map/x.png');
    await tester.pumpWidget(
      wrap(const CampusMap(avatarOffset: Offset(10, 10), config: config)),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('passes the chosen appearance to the walking map sprite', (
    tester,
  ) async {
    const style = AvatarStyle(
      hair: AvatarHair.ponytail,
      outfit: AvatarOutfit.lilac,
      accessory: AvatarAccessory.bow,
    );
    await tester.pumpWidget(
      wrap(const CampusMap(avatarOffset: Offset(100, 200), avatarStyle: style)),
    );

    expect(tester.widget<PixelAvatar>(find.byType(PixelAvatar)).style, style);
  });

  testWidgets('falls back to the painted campus if an image is missing', (
    tester,
  ) async {
    const config = CampusMapConfig(
      backgroundAssetPath: 'assets/map/missing.png',
    );
    await tester.pumpWidget(
      wrap(const CampusMap(avatarOffset: null, config: config)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PixelCampusPainter,
      ),
      findsOneWidget,
    );
  });

  testWidgets('places the avatar at the offset and glides to a new one', (
    tester,
  ) async {
    const size = 96.0;
    await tester.pumpWidget(
      wrap(const CampusMap(avatarOffset: Offset(100, 200), interactive: false)),
    );
    expect(find.byType(PixelAvatar), findsOneWidget);
    var positioned = avatarPositioned(tester);
    expect(positioned.left, 100 - size / 2);
    expect(positioned.top, 200 - size * 0.92);

    await tester.pumpWidget(
      wrap(const CampusMap(avatarOffset: Offset(300, 500), interactive: false)),
    );
    // Mid-flight: the avatar walks and sits between the two points.
    await tester.pump(const Duration(milliseconds: 200));
    positioned = avatarPositioned(tester);
    expect(positioned.left, greaterThan(100 - size / 2));
    expect(positioned.left, lessThan(300 - size / 2));
    expect(
      tester.widget<PixelAvatar>(find.byType(PixelAvatar)).walking,
      isTrue,
    );

    await tester.pumpAndSettle();
    positioned = avatarPositioned(tester);
    expect(positioned.left, 300 - size / 2);
    expect(positioned.top, 500 - size * 0.92);
    expect(
      tester.widget<PixelAvatar>(find.byType(PixelAvatar)).walking,
      isFalse,
    );
  });

  testWidgets('camera follows the avatar and can recenter after manual pan', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapViewport(const CampusMap(avatarOffset: Offset(360, 645))),
    );
    await tester.pumpAndSettle();
    var position = cameraPosition(tester, const Offset(360, 645));
    expect(position.dx, closeTo(180, 1));
    expect(position.dy, closeTo(250, 1));

    await tester.pumpWidget(
      wrapViewport(const CampusMap(avatarOffset: Offset(400, 700))),
    );
    await tester.pumpAndSettle();
    position = cameraPosition(tester, const Offset(400, 700));
    expect(position.dx, closeTo(180, 1));
    expect(position.dy, closeTo(250, 1));

    await tester.drag(find.byType(InteractiveViewer), const Offset(-50, 0));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PixelIconButton &&
            widget.semanticLabel == 'Centrar en mi ubicación',
      ),
      findsOneWidget,
    );
    final panned = cameraPosition(tester, const Offset(400, 700));

    await tester.pumpWidget(
      wrapViewport(const CampusMap(avatarOffset: Offset(350, 650))),
    );
    await tester.pumpAndSettle();
    position = cameraPosition(tester, const Offset(400, 700));
    expect(position.dx, closeTo(panned.dx, 1));
    expect(position.dy, closeTo(panned.dy, 1));

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is PixelIconButton &&
            widget.semanticLabel == 'Centrar en mi ubicación',
      ),
    );
    await tester.pumpAndSettle();
    position = cameraPosition(tester, const Offset(350, 650));
    expect(position.dx, closeTo(180, 1));
    expect(position.dy, closeTo(250, 1));
  });

  testWidgets('PixelAvatar alternates frames only while walking', (
    tester,
  ) async {
    int frame() =>
        (tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byType(PixelAvatar),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as PixelAvatarPainter)
            .frame;

    await tester.pumpWidget(wrap(const Center(child: PixelAvatar())));
    expect(frame(), 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(frame(), 0, reason: 'idle avatar does not animate');

    await tester.pumpWidget(
      wrap(const Center(child: PixelAvatar(walking: true))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(frame(), 1);
    await tester.pump(const Duration(milliseconds: 250));
    expect(frame(), 0);

    await tester.pumpWidget(wrap(const Center(child: PixelAvatar())));
    await tester.pump();
    expect(frame(), 0);
  });
}
