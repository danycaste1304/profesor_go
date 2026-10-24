import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Small map stickers for confirmed event landmarks. These are illustrative
/// waypoints, never locations assigned to the professors or their NFC tags.
/// Coordinates refer to the bundled 720 x 1290 quadrangles illustration.
class FairLandmarksPainter extends CustomPainter {
  const FairLandmarksPainter();

  static const _ink = AppColors.text;
  static const _red = AppColors.danger;
  static const _cream = Color(0xFFFFFAE9);
  static const _pink = Color(0xFFFFB9CC);
  static const _mint = Color(0xFF9EE5BE);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 720, size.height / 1290);
    final paint = Paint()..isAntiAlias = false;

    void rect(
      double left,
      double top,
      double width,
      double height,
      Color color,
    ) {
      paint.color = color;
      canvas.drawRect(Rect.fromLTWH(left, top, width, height), paint);
    }

    void polygon(List<Offset> points, Color color) {
      paint.color = color;
      canvas.drawPath(Path()..addPolygon(points, true), paint);
    }

    // The tent is a map marker on the near quadrangle, not a building painted
    // into the original campus artwork. Its pin ends at (250, 1008).
    polygon(const [
      Offset(238, 980),
      Offset(262, 980),
      Offset(250, 1008),
    ], _ink);
    polygon(const [
      Offset(243, 979),
      Offset(257, 979),
      Offset(250, 997),
    ], AppColors.accent);
    rect(145, 831, 210, 151, _ink);
    rect(150, 836, 200, 141, _cream);

    // Striped roof and two little booths under one shared tent.
    polygon(const [
      Offset(157, 903),
      Offset(190, 844),
      Offset(310, 844),
      Offset(343, 903),
    ], _ink);
    polygon(const [
      Offset(165, 899),
      Offset(194, 850),
      Offset(306, 850),
      Offset(335, 899),
    ], _red);
    polygon(const [
      Offset(194, 850),
      Offset(222, 850),
      Offset(207, 899),
      Offset(175, 899),
    ], _cream);
    polygon(const [
      Offset(250, 850),
      Offset(278, 850),
      Offset(293, 899),
      Offset(222, 899),
    ], _cream);
    rect(165, 899, 170, 10, _ink);
    rect(171, 909, 158, 30, _cream);
    rect(245, 909, 10, 30, _ink);
    rect(171, 936, 158, 5, _ink);
    rect(155, 946, 190, 28, AppColors.surfaceAlt);
    rect(155, 946, 190, 4, AppColors.accentAlt);

    void label(
      String value,
      double centerX,
      double top,
      double fontSize,
      Color color,
    ) {
      final text = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: AppTheme.displayFontFamily,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(centerX - text.width / 2, top));
    }

    label('MAC', 208, 907, 26, _ink);
    label('COMP', 289, 907, 26, _ink);
    label('CARPA POLITÉCNICO', 250, 947, 25, _ink);

    // The user marked the laboratory entrance on the campus reference map.
    // This sign gives its direction from the quadrangles; the perspective
    // artwork does not support placing that entrance at a precise map point.
    rect(550, 663, 133, 43, _ink);
    rect(555, 668, 123, 33, _cream);
    polygon(
      const [Offset(683, 663), Offset(709, 685), Offset(683, 706)],
      _ink,
    );
    polygon(
      const [Offset(682, 672), Offset(697, 685), Offset(682, 697)],
      AppColors.accent,
    );
    label('ENTRADA LAB', 616, 669, 25, _ink);

    // A few small flowers soften the sticker without recoloring the original
    // quadrangles image or hiding the paths.
    void flower(double x, double y, Color petals) {
      rect(x + 5, y, 5, 5, petals);
      rect(x, y + 5, 5, 5, petals);
      rect(x + 10, y + 5, 5, 5, petals);
      rect(x + 5, y + 10, 5, 5, petals);
      rect(x + 5, y + 5, 5, 5, AppColors.accent);
      rect(x + 5, y + 15, 5, 8, AppColors.success);
    }

    flower(119, 945, _pink);
    flower(365, 924, _mint);
    flower(377, 963, _pink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FairLandmarksPainter oldDelegate) => false;
}
