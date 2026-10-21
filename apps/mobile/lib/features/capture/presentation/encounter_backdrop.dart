import 'package:flutter/material.dart';

/// Original tile-style scene behind a professor encounter.
class EncounterBackdrop extends StatelessWidget {
  const EncounterBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(painter: EncounterBackdropPainter()),
    );
  }
}

class EncounterBackdropPainter extends CustomPainter {
  const EncounterBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320, size.height / 560);
    final paint = Paint()..isAntiAlias = false;
    void px(double x, double y, double w, double h, Color color) {
      paint.color = color;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
    }

    px(0, 0, 320, 560, const Color(0xFFD7C490));
    for (var y = 0; y < 310; y += 12) {
      px(0, y.toDouble(), 320, 5, const Color(0xFFE4D2A1));
      px(0, y + 8, 320, 2, const Color(0xFFC9B480));
    }
    px(0, 305, 320, 255, const Color(0xFF94C99E));
    px(0, 306, 320, 8, const Color(0xFF5E9F78));
    for (var y = 326; y < 560; y += 24) {
      for (var x = (y ~/ 24).isEven ? 0 : 12; x < 320; x += 24) {
        px(x.toDouble(), y.toDouble(), 4, 3, const Color(0xFFB7DBA6));
        px(x + 7, y + 12, 3, 4, const Color(0xFF70B48A));
      }
    }

    // Stepped platforms frame the professor and the player's throw area.
    px(92, 222, 136, 13, const Color(0xFF927B64));
    px(77, 235, 166, 14, const Color(0xFF927B64));
    px(64, 249, 192, 8, const Color(0xFF927B64));
    px(92, 214, 136, 11, const Color(0xFFF0E1A5));
    px(77, 225, 166, 12, const Color(0xFFF0E1A5));
    px(64, 237, 192, 12, const Color(0xFFF0E1A5));
    px(39, 465, 242, 12, const Color(0xFF619976));
    px(24, 477, 272, 14, const Color(0xFF619976));
    px(39, 454, 242, 12, const Color(0xFFC4D79D));
    px(24, 466, 272, 12, const Color(0xFFC4D79D));

    // Blocky trees at the edges keep the center clear for the mini-game.
    for (final x in <double>[6, 282]) {
      px(x + 11, 270, 15, 122, const Color(0xFF8F7259));
      px(x, 249, 37, 75, const Color(0xFF4A9D6A));
      px(x + 5, 230, 28, 79, const Color(0xFF6AB47A));
      px(x + 4, 250, 14, 17, const Color(0xFF8CCD8B));
      px(x + 27, 286, 8, 16, const Color(0xFF3E865E));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant EncounterBackdropPainter oldDelegate) => false;
}
