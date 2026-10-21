import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Original 16 × 16 pixel capture ball with a raised center button.
class CaptureBall extends StatelessWidget {
  const CaptureBall({
    super.key,
    this.size = 96,
    this.topColor = AppColors.danger,
    this.bottomColor = const Color(0xFFFFF8DF),
    this.bandColor = AppColors.text,
    this.semanticLabel = 'Bola de captura',
  });

  final double size;
  final Color topColor;
  final Color bottomColor;
  final Color bandColor;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: CaptureBallPainter(
          topColor: topColor,
          bottomColor: bottomColor,
          bandColor: bandColor,
        ),
      ),
    );
  }
}

class CaptureBallPainter extends CustomPainter {
  const CaptureBallPainter({
    required this.topColor,
    required this.bottomColor,
    required this.bandColor,
  });

  final Color topColor;
  final Color bottomColor;
  final Color bandColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 16, size.height / 16);
    final paint = Paint()..isAntiAlias = false;
    void px(int x, int y, int w, int h, Color color) {
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
        paint,
      );
    }

    const outline = Color(0xFF20374A);
    const upperShade = Color(0xFFB9374B);
    const lowerShade = Color(0xFFD9E9E6);
    const spans = <(int, int)>[
      (6, 4),
      (4, 8),
      (3, 10),
      (2, 12),
      (1, 14),
      (1, 14),
      (0, 16),
      (0, 16),
      (0, 16),
      (0, 16),
      (1, 14),
      (1, 14),
      (2, 12),
      (3, 10),
      (4, 8),
      (6, 4),
    ];
    for (var y = 0; y < spans.length; y++) {
      final (x, width) = spans[y];
      px(x, y, width, 1, outline);
      if (y >= 1 && y <= 6) {
        px(x + 1, y, width - 2, 1, y >= 5 ? upperShade : topColor);
      } else if (y >= 9 && y <= 14) {
        px(x + 1, y, width - 2, 1, y >= 12 ? lowerShade : bottomColor);
      }
    }
    px(1, 7, 14, 2, bandColor);
    px(3, 3, 3, 1, const Color(0xFFFFB6A7));
    px(2, 4, 2, 1, const Color(0xFFFFB6A7));
    px(11, 11, 2, 1, const Color(0xFFFFFFFF));
    px(5, 5, 6, 6, outline);
    px(6, 6, 4, 4, const Color(0xFF8CD1D9));
    px(7, 7, 2, 2, const Color(0xFFF9FCF2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CaptureBallPainter old) =>
      old.topColor != topColor ||
      old.bottomColor != bottomColor ||
      old.bandColor != bandColor;
}
