import 'package:flutter/widgets.dart';

/// Paints a chunky pixel-art frame: outline with stepped corners, a flat face,
/// and (for buttons) a light bevel on the top/left edges and a dark one on the
/// bottom/right.
///
/// Everything is drawn from axis-aligned rectangles (no anti-aliasing) in
/// blocks of [pixel] logical px, so it stays crisp at any size. A [raised]
/// frame shows a solid slab one block below the face; when [pressed] the face
/// drops onto it and the bevel flips, which reads as a physical push.
/// [PixelFramePainter.flat] is the shadowless variant used by containers.
class PixelFramePainter extends CustomPainter {
  const PixelFramePainter({
    required this.face,
    required this.outline,
    required this.highlight,
    required this.shade,
    this.pressed = false,
    this.pixel = defaultPixel,
  }) : raised = true,
       bevel = true;

  /// Container frame: just outline + face, no slab and no bevel.
  const PixelFramePainter.flat({
    required this.face,
    required this.outline,
    this.pixel = defaultPixel,
  }) : highlight = face,
       shade = face,
       pressed = false,
       raised = false,
       bevel = false;

  /// Medium pixel size, also the height of the raised slab.
  static const double defaultPixel = 4;

  final Color face;
  final Color outline;
  final Color highlight;
  final Color shade;
  final bool pressed;
  final bool raised;
  final bool bevel;
  final double pixel;

  @override
  void paint(Canvas canvas, Size size) {
    final p = pixel;
    final paint = Paint()..isAntiAlias = false;

    // The slab lives in the bottom block, so a raised face always leaves room.
    final slab = raised ? p : 0.0;
    final body = Rect.fromLTWH(
      0,
      pressed ? slab : 0,
      size.width,
      size.height - slab,
    );

    if (raised && !pressed) {
      paint.color = outline;
      canvas.drawPath(_stepped(body.shift(Offset(0, p)), p), paint);
    }

    paint.color = outline;
    canvas.drawPath(_stepped(body, p), paint);

    final inner = body.deflate(p);
    paint.color = face;
    canvas.drawRect(inner, paint);

    if (!bevel) return;
    final light = pressed ? shade : highlight;
    final dark = pressed ? highlight : shade;
    paint.color = light;
    canvas.drawRect(Rect.fromLTWH(inner.left, inner.top, inner.width, p), paint);
    canvas.drawRect(Rect.fromLTWH(inner.left, inner.top, p, inner.height), paint);
    paint.color = dark;
    canvas.drawRect(
      Rect.fromLTWH(inner.left, inner.bottom - p, inner.width, p),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(inner.right - p, inner.top, p, inner.height),
      paint,
    );
  }

  /// Rectangle with one block cut from each corner (union of two rects).
  static Path _stepped(Rect r, double p) => Path()
    ..addRect(Rect.fromLTRB(r.left + p, r.top, r.right - p, r.bottom))
    ..addRect(Rect.fromLTRB(r.left, r.top + p, r.right, r.bottom - p));

  @override
  bool shouldRepaint(covariant PixelFramePainter old) =>
      old.face != face ||
      old.outline != outline ||
      old.highlight != highlight ||
      old.shade != shade ||
      old.pressed != pressed ||
      old.raised != raised ||
      old.bevel != bevel ||
      old.pixel != pixel;
}
