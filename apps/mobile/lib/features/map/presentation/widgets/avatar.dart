import 'package:flutter/material.dart';

import '../../../avatar/avatar_style.dart';

/// The player's customizable 24 x 24 chibi trainer.
///
/// While [walking] is true a 2-frame walk cycle runs (legs apart / legs
/// together with a 1-pixel bob); otherwise the idle frame is shown and no
/// ticker is active. Smooth movement across the map is handled by the parent
/// (see `CampusMap`, which wraps it in an `AnimatedPositioned`).
class PixelAvatar extends StatefulWidget {
  const PixelAvatar({
    super.key,
    this.size = 64,
    this.walking = false,
    this.frameDuration = const Duration(milliseconds: 250),
    this.semanticLabel = 'Tu avatar',
    this.style = const AvatarStyle(),
  });

  /// Width and height in logical pixels (the sprite is square).
  final double size;
  final bool walking;

  /// Duration of each of the two walk frames.
  final Duration frameDuration;
  final String semanticLabel;
  final AvatarStyle style;

  @override
  State<PixelAvatar> createState() => _PixelAvatarState();
}

class _PixelAvatarState extends State<PixelAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.frameDuration * 2,
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(PixelAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frameDuration != widget.frameDuration) {
      _controller.duration = widget.frameDuration * 2;
    }
    if (oldWidget.walking != widget.walking) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.walking) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: PixelAvatarPainter(
            frame: _controller.value < 0.5 ? 0 : 1,
            style: widget.style,
          ),
        ),
      ),
    );
  }
}

/// Paints the trainer with crisp square pixels and a two-frame walking cycle.
class PixelAvatarPainter extends CustomPainter {
  const PixelAvatarPainter({this.frame = 0, this.style = const AvatarStyle()});

  final int frame;
  final AvatarStyle style;

  static const _skin = Color(0xFFFFD7B5);
  static const _skinShade = Color(0xFFEAB692);
  static const _hair = Color(0xFF4B3445);
  static const _hairLight = Color(0xFF735169);
  static const _outline = Color(0xFF35445C);
  static const _pants = Color(0xFF6478A2);
  static const _shoes = Color(0xFF38465D);
  static const _blush = Color(0xFFF595A3);
  static const _cream = Color(0xFFFFF7E8);
  static const _glasses = Color(0xFF4A7390);

  Color get _shirt => switch (style.outfit) {
    AvatarOutfit.turquoise => const Color(0xFF67D1CA),
    AvatarOutfit.pink => const Color(0xFFFF93B4),
    AvatarOutfit.lilac => const Color(0xFFAD9BF0),
  };

  Color get _shirtShade => switch (style.outfit) {
    AvatarOutfit.turquoise => const Color(0xFF329EAA),
    AvatarOutfit.pink => const Color(0xFFDB668E),
    AvatarOutfit.lilac => const Color(0xFF8075C7),
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..isAntiAlias = false;
    void px(int x, int y, int w, int h, Color color) {
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
        paint,
      );
    }

    // Ground shadow and oversized head keep the trainer legible on the map.
    px(4, 22, 16, 1, const Color(0x66467072));
    px(7, 23, 10, 1, const Color(0x44507A79));
    final walk = frame == 1;
    px(walk ? 6 : 7, 18, 5, 4, _outline);
    px(walk ? 13 : 12, 18, 5, 4, _outline);
    px(walk ? 7 : 8, 18, 3, 3, _pants);
    px(walk ? 14 : 13, 18, 3, 3, _pants);
    px(walk ? 5 : 6, 21, 6, 2, _shoes);
    px(walk ? 14 : 12, 21, 6, 2, _shoes);
    px(walk ? 6 : 7, 21, 3, 1, _cream);
    px(walk ? 15 : 13, 21, 3, 1, _cream);

    // Tiny hoodie, sleeves and mitten-sized hands.
    px(5, 14, 14, 6, _outline);
    px(6, 14, 12, 5, _shirt);
    px(7, 18, 10, 1, _shirtShade);
    px(10, 16, 4, 2, _cream);
    px(11, 16, 2, 2, const Color(0xFFFFCF5C));
    px(walk ? 3 : 4, 15, 3, 4, _outline);
    px(walk ? 4 : 5, 15, 2, 3, _shirt);
    px(walk ? 3 : 4, 18, 3, 2, _skin);
    px(walk ? 18 : 17, 15, 3, 4, _outline);
    px(walk ? 18 : 17, 15, 2, 3, _shirt);
    px(walk ? 19 : 18, 18, 3, 2, _skin);

    // Hair behind the cheeks varies in silhouette, not only color.
    if (style.hair == AvatarHair.ponytail) {
      px(17, 5, 4, 5, _outline);
      px(18, 9, 4, 5, _outline);
      px(19, 13, 3, 3, _outline);
      px(18, 6, 2, 4, _hair);
      px(19, 10, 2, 5, _hair);
      px(20, 11, 1, 3, _hairLight);
    } else if (style.hair == AvatarHair.curls) {
      // A scalloped silhouette and separate highlighted coils stay readable
      // even when the player wears a cap or the sprite is small on the map.
      px(4, 3, 5, 12, _outline);
      px(3, 5, 4, 4, _outline);
      px(3, 10, 4, 4, _outline);
      px(5, 14, 3, 2, _outline);
      px(15, 3, 5, 12, _outline);
      px(17, 5, 4, 4, _outline);
      px(17, 10, 4, 4, _outline);
      px(16, 14, 3, 2, _outline);
      px(5, 4, 3, 10, _hair);
      px(4, 6, 3, 2, _hair);
      px(4, 11, 3, 2, _hair);
      px(6, 14, 2, 1, _hair);
      px(16, 4, 3, 10, _hair);
      px(17, 6, 3, 2, _hair);
      px(17, 11, 3, 2, _hair);
      px(16, 14, 2, 1, _hair);
      px(5, 5, 2, 1, _hairLight);
      px(4, 7, 2, 1, _hairLight);
      px(5, 9, 2, 1, _hairLight);
      px(4, 12, 2, 1, _hairLight);
      px(17, 5, 2, 1, _hairLight);
      px(18, 7, 2, 1, _hairLight);
      px(17, 9, 2, 1, _hairLight);
      px(18, 12, 2, 1, _hairLight);
    } else {
      px(5, 5, 3, 9, _outline);
      px(16, 5, 3, 9, _outline);
      px(6, 6, 2, 7, _hair);
      px(16, 6, 2, 7, _hair);
    }

    // Rounded face, big sparkling eyes, blush and a one-pixel smile.
    px(7, 4, 10, 11, _outline);
    px(6, 7, 12, 6, _outline);
    px(7, 6, 10, 8, _skin);
    px(8, 13, 8, 1, _skinShade);
    px(8, 9, 2, 3, _outline);
    px(14, 9, 2, 3, _outline);
    px(8, 9, 1, 1, _cream);
    px(14, 9, 1, 1, _cream);
    px(7, 12, 2, 1, _blush);
    px(15, 12, 2, 1, _blush);
    px(11, 12, 2, 1, _skinShade);
    px(12, 13, 1, 1, _outline);

    // Fringe and crown frame the face. The cap, glasses and bow sit on top.
    if (style.hair == AvatarHair.curls) {
      px(5, 3, 14, 5, _outline);
      px(6, 2, 4, 4, _outline);
      px(10, 1, 4, 4, _outline);
      px(14, 2, 4, 4, _outline);
      px(6, 4, 12, 3, _hair);
      px(7, 3, 2, 3, _hair);
      px(11, 2, 2, 4, _hair);
      px(15, 3, 2, 3, _hair);
      px(6, 6, 3, 2, _hair);
      px(10, 6, 4, 2, _hair);
      px(15, 6, 3, 2, _hair);
      px(7, 3, 2, 1, _hairLight);
      px(11, 2, 2, 1, _hairLight);
      px(15, 3, 2, 1, _hairLight);
      px(6, 5, 2, 1, _hairLight);
      px(10, 5, 2, 1, _hairLight);
      px(15, 5, 2, 1, _hairLight);
    } else {
      px(6, 3, 12, 5, _outline);
      px(7, 3, 10, 4, _hair);
      px(8, 3, 7, 1, _hairLight);
      if (style.hair == AvatarHair.ponytail) {
        px(7, 6, 6, 2, _hair);
        px(15, 5, 3, 3, _hair);
        px(16, 4, 3, 2, _hairLight);
      } else {
        px(7, 6, 5, 2, _hair);
        px(14, 6, 3, 1, _hair);
      }
    }

    switch (style.accessory) {
      case AvatarAccessory.cap:
        px(6, 1, 12, 4, _outline);
        px(7, 1, 10, 3, const Color(0xFFFFD460));
        px(9, 1, 6, 1, const Color(0xFFFFE793));
        px(4, 4, 16, 2, _outline);
        px(5, 4, 14, 1, const Color(0xFFFFD460));
        px(11, 2, 2, 2, _cream);
      case AvatarAccessory.glasses:
        px(8, 10, 3, 2, const Color(0xFFD8F0F5));
        px(13, 10, 3, 2, const Color(0xFFD8F0F5));
        px(9, 10, 1, 2, _outline);
        px(14, 10, 1, 2, _outline);
        px(9, 10, 1, 1, _cream);
        px(14, 10, 1, 1, _cream);
        px(7, 9, 5, 1, _glasses);
        px(12, 9, 5, 1, _glasses);
        px(7, 10, 1, 2, _glasses);
        px(11, 10, 1, 2, _glasses);
        px(12, 10, 1, 2, _glasses);
        px(16, 10, 1, 2, _glasses);
        px(8, 12, 3, 1, _glasses);
        px(13, 12, 3, 1, _glasses);
      case AvatarAccessory.bow:
        px(15, 2, 3, 4, _outline);
        px(19, 2, 3, 4, _outline);
        px(16, 3, 2, 2, const Color(0xFFFF8FAE));
        px(19, 3, 2, 2, const Color(0xFFFF8FAE));
        px(18, 4, 1, 2, const Color(0xFFFFD460));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PixelAvatarPainter old) =>
      old.frame != frame || old.style != style;
}
