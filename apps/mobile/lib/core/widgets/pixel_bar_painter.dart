import 'package:flutter/widgets.dart';

import 'pixel_frame_painter.dart';

/// Pixel-art progress track: a flat [PixelFramePainter] frame with a fill that
/// grows in whole [pixel] blocks (so it advances in visible steps), lit on the
/// top row and shaded on the bottom row like the buttons.
class PixelBarPainter extends CustomPainter {
  const PixelBarPainter({
    required this.ratio,
    required this.track,
    required this.fill,
    required this.outline,
    required this.pixel,
  });

  /// Filled fraction, 0..1.
  final double ratio;
  final Color track;
  final Color fill;
  final Color outline;
  final double pixel;

  @override
  void paint(Canvas canvas, Size size) {
    PixelFramePainter.flat(
      face: track,
      outline: outline,
      pixel: pixel,
    ).paint(canvas, size);

    final inner = Offset(pixel, pixel) & Size(
      size.width - 2 * pixel,
      size.height - 2 * pixel,
    );
    if (inner.width <= 0 || inner.height <= 0 || ratio <= 0) return;

    // Whole blocks only; any progress shows at least one block.
    final blocks = (inner.width * ratio / pixel).floor();
    final width = (blocks < 1 ? 1 : blocks) * pixel;
    final bar = Rect.fromLTWH(inner.left, inner.top, width, inner.height);

    final paint = Paint()..isAntiAlias = false;
    paint.color = fill;
    canvas.drawRect(bar, paint);
    if (bar.height >= 3 * pixel) {
      paint.color = Color.lerp(fill, const Color(0xFFFFFFFF), 0.5)!;
      canvas.drawRect(
        Rect.fromLTWH(bar.left, bar.top, bar.width, pixel),
        paint,
      );
      paint.color = Color.lerp(fill, outline, 0.3)!;
      canvas.drawRect(
        Rect.fromLTWH(bar.left, bar.bottom - pixel, bar.width, pixel),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PixelBarPainter old) =>
      old.ratio != ratio ||
      old.track != track ||
      old.fill != fill ||
      old.outline != outline ||
      old.pixel != pixel;
}
