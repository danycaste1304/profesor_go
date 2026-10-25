import 'package:flutter/widgets.dart';

/// A square pixel glyph written as text: `#` is a filled block, anything else
/// is empty. Rows are separated by `\n`.
///
/// The length check runs at compile time for const glyphs, so a malformed
/// grid cannot be built.
class PixelIconData {
  const PixelIconData(this.art, {this.size = 12, this.cell = 2})
    : assert(
        art.length == size * size + (size - 1),
        'A glyph is `size` rows of `size` columns separated by newlines.',
      );

  final String art;

  /// Blocks per side.
  final int size;

  /// Side of one block, in logical px.
  final double cell;

  /// Total side of the icon, in logical px.
  double get extent => size * cell;
}

/// Pixel-art icon: one square block per `#` of [data], drawn without
/// anti-aliasing like the frames of [PixelButton] and [PixelCard]. Its size is
/// set by the glyph itself ([PixelIconData.extent]).
class PixelIcon extends StatelessWidget {
  const PixelIcon(this.data, {super.key, this.color});

  final PixelIconData data;

  /// Defaults to the ambient [IconTheme] color, like [Icon].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final paintColor =
        color ?? IconTheme.of(context).color ?? const Color(0xFF000000);
    return SizedBox.square(
      dimension: data.extent,
      child: CustomPaint(painter: _PixelIconPainter(data, paintColor)),
    );
  }
}

class _PixelIconPainter extends CustomPainter {
  const _PixelIconPainter(this.data, this.color);

  final PixelIconData data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = false
      ..color = color;
    final rows = data.art.split('\n');
    // The glyph asks for its own size, but a parent can force a bigger box
    // (e.g. InputDecoration gives a prefixIcon at least 48 x 48): center the
    // art in it instead of leaving it in the top-left corner.
    canvas.save();
    canvas.translate(
      (size.width - data.extent) / 2,
      (size.height - data.extent) / 2,
    );
    for (var y = 0; y < data.size; y++) {
      var x = 0;
      while (x < data.size) {
        if (rows[y][x] != '#') {
          x++;
          continue;
        }
        // One rect per horizontal run keeps the draw calls low.
        final start = x;
        while (x < data.size && rows[y][x] == '#') {
          x++;
        }
        canvas.drawRect(
          Rect.fromLTWH(
            start * data.cell,
            y * data.cell,
            (x - start) * data.cell,
            data.cell,
          ),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PixelIconPainter old) =>
      old.data != data || old.color != color;
}
