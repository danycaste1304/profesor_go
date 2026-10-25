import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'pixel_frame_painter.dart';

/// Pixel-art circle with the same look as [PixelFramePainter]: a one-block
/// outline, a flat face, light bevel on the top/left rim and dark on the
/// bottom/right, plus a solid slab below when raised. A [pressed] circle drops
/// onto the slab and the bevel flips.
///
/// The circle is a grid of [pixel]-sized blocks, so it stays crisp (no
/// anti-aliasing). The canvas height must leave one block for the slab.
class PixelCirclePainter extends CustomPainter {
  const PixelCirclePainter({
    required this.face,
    required this.outline,
    required this.highlight,
    required this.shade,
    this.pressed = false,
    this.pixel = PixelFramePainter.defaultPixel,
  });

  final Color face;
  final Color outline;
  final Color highlight;
  final Color shade;
  final bool pressed;
  final double pixel;

  /// Blocks across the circle that fit in [size] (slab block excluded).
  static int cellsFor(Size size, double pixel) =>
      math.min(size.width, size.height - pixel) ~/ pixel;

  @override
  void paint(Canvas canvas, Size size) {
    final p = pixel;
    final n = cellsFor(size, p);
    if (n < 3) return;

    // Center the block grid horizontally; the slab block sits under it.
    final left = (size.width - n * p) / 2;
    final top = pressed ? p : 0.0;

    final inside = List.generate(
      n,
      (y) => List.generate(n, (x) => _inside(x, y, n)),
    );
    bool at(int x, int y) => x >= 0 && y >= 0 && x < n && y < n && inside[y][x];
    bool isOutline(int x, int y) =>
        at(x, y) &&
        !(at(x - 1, y) && at(x + 1, y) && at(x, y - 1) && at(x, y + 1));

    final paint = Paint()..isAntiAlias = false;
    void cell(int x, int y, double dy, Color color) {
      paint.color = color;
      canvas.drawRect(Rect.fromLTWH(left + x * p, dy + y * p, p, p), paint);
    }

    if (!pressed) {
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < n; x++) {
          if (inside[y][x]) cell(x, y, p, outline);
        }
      }
    }

    final light = pressed ? shade : highlight;
    final dark = pressed ? highlight : shade;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (!inside[y][x]) continue;
        if (isOutline(x, y)) {
          cell(x, y, top, outline);
          continue;
        }
        final towardLight = isOutline(x - 1, y) || isOutline(x, y - 1);
        final towardDark = isOutline(x + 1, y) || isOutline(x, y + 1);
        final color = towardLight && !towardDark
            ? light
            : towardDark && !towardLight
            ? dark
            : face;
        cell(x, y, top, color);
      }
    }
  }

  /// Whether the block (x, y) of an n x n grid lies inside the circle.
  static bool _inside(int x, int y, int n) {
    final c = n / 2;
    final dx = x + 0.5 - c;
    final dy = y + 0.5 - c;
    return math.sqrt(dx * dx + dy * dy) <= c;
  }

  @override
  bool shouldRepaint(covariant PixelCirclePainter old) =>
      old.face != face ||
      old.outline != outline ||
      old.highlight != highlight ||
      old.shade != shade ||
      old.pressed != pressed ||
      old.pixel != pixel;
}
