import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../avatar/avatar_style.dart';
import '../../domain/campus_map_config.dart';
import 'avatar.dart';

/// Illustrated campus map with the player's avatar layered on top.
///
/// The map is laid out in logical units ([CampusMapConfig.mapWidth] x
/// [CampusMapConfig.mapHeight]), scaled with a [FittedBox] so the whole
/// campus fits the available space, and wrapped in an [InteractiveViewer]
/// for pinch-zoom and panning. [avatarOffset] is expressed in those logical
/// units (use [CampusMapConfig.toMapOffset]); `null` hides the avatar.
///
/// Background: [CampusMapConfig.backgroundAssetPath] when set and loadable,
/// otherwise the built-in [PixelCampusPainter].
class CampusMap extends StatefulWidget {
  const CampusMap({
    super.key,
    required this.avatarOffset,
    this.config = CampusMapConfig.defaults,
    this.avatarSize = 96,
    this.avatarStyle = const AvatarStyle(),
    this.interactive = true,
    this.moveDuration = const Duration(milliseconds: 450),
    this.maxScale = 4,
  });

  /// Avatar position in logical map units (feet anchor). `null` = hidden.
  final Offset? avatarOffset;
  final CampusMapConfig config;

  /// Avatar sprite size in logical map units.
  final double avatarSize;
  final AvatarStyle avatarStyle;

  /// Enables pinch-zoom / pan.
  final bool interactive;

  /// Duration of the glide between two avatar positions (300-600 ms).
  final Duration moveDuration;
  final double maxScale;

  /// Key of the positioned avatar (tests read its `left` / `top`).
  static const Key avatarKey = Key('campus-map-avatar');

  @override
  State<CampusMap> createState() => _CampusMapState();
}

class _CampusMapState extends State<CampusMap> {
  /// Asset paths that failed to load: skipped on later builds so the map does
  /// not flash blank while retrying an image that is known to be missing.
  static final Set<String> _missingAssets = {};

  bool _walking = false;

  @override
  void didUpdateWidget(CampusMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final from = oldWidget.avatarOffset;
    final to = widget.avatarOffset;
    if (from != null && to != null && from != to) _walking = true;
  }

  void _onMoveEnd() {
    if (mounted && _walking) setState(() => _walking = false);
  }

  Widget _background() {
    final painted = RepaintBoundary(
      child: CustomPaint(
        size: widget.config.mapSize,
        painter: const PixelCampusPainter(),
      ),
    );
    final path = widget.config.backgroundAssetPath;
    if (path == null || _missingAssets.contains(path)) return painted;
    return Image.asset(
      path,
      width: widget.config.mapWidth,
      height: widget.config.mapHeight,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) {
        _missingAssets.add(path);
        return painted;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final offset = widget.avatarOffset;
    final size = widget.avatarSize;

    final map = SizedBox(
      width: config.mapWidth,
      height: config.mapHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _background()),
          if (offset != null)
            AnimatedPositioned(
              key: CampusMap.avatarKey,
              duration: widget.moveDuration,
              curve: Curves.easeInOut,
              left: offset.dx - size / 2,
              // The sprite's feet sit at ~92% of its height.
              top: offset.dy - size * 0.92,
              width: size,
              height: size,
              onEnd: _onMoveEnd,
              child: PixelAvatar(
                size: size,
                walking: _walking,
                style: widget.avatarStyle,
              ),
            ),
        ],
      ),
    );

    final fitted = Center(child: FittedBox(child: map));

    return Semantics(
      label: 'Mapa del campus',
      container: true,
      child: ColoredBox(
        color: PixelCampusPainter.grassA,
        child: widget.interactive
            ? InteractiveViewer(
                minScale: 1,
                maxScale: widget.maxScale,
                child: fitted,
              )
            : fitted,
      ),
    );
  }
}

/// Illustrated fallback map for the demo campus. All geometry is original and
/// stays in logical map coordinates so the GPS projection continues to work.
/// Replace it with a surveyed campus asset when the fair location is known.
class PixelCampusPainter extends CustomPainter {
  const PixelCampusPainter();

  static const Color grassA = Color(0xFFB9DFA9);
  static const Color _grassLight = Color(0xFFD1E9BB);
  static const Color _grassDark = Color(0xFF9FD098);
  static const Color _road = Color(0xFFF5F5E9);
  static const Color _roadEdge = Color(0xFFD7E3D0);
  static const Color _water = Color(0xFF8BDBE8);
  static const Color _ink = Color(0xFF3E6774);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 900, size.height / 1200);
    final paint = Paint()..isAntiAlias = true;

    void rounded(Rect rect, Color color, double radius) {
      paint
        ..style = PaintingStyle.fill
        ..color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
    }

    void oval(Rect rect, Color color) {
      paint
        ..style = PaintingStyle.fill
        ..color = color;
      canvas.drawOval(rect, paint);
    }

    canvas.drawColor(grassA, BlendMode.src);

    // Broad lawn shapes soften the map without turning it into a checkerboard.
    oval(const Rect.fromLTWH(-170, -110, 570, 550), _grassLight);
    oval(const Rect.fromLTWH(540, 80, 430, 440), _grassDark);
    oval(const Rect.fromLTWH(-130, 650, 450, 500), _grassDark);
    oval(const Rect.fromLTWH(410, 790, 630, 490), _grassLight);

    void road(Path path, double width) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width + 20
        ..color = _roadEdge;
      canvas.drawPath(path, paint);
      paint
        ..strokeWidth = width
        ..color = _road;
      canvas.drawPath(path, paint);
      paint.style = PaintingStyle.fill;
    }

    road(
      Path()
        ..moveTo(450, -80)
        ..cubicTo(410, 250, 490, 470, 445, 650)
        ..cubicTo(410, 840, 485, 1010, 455, 1280),
      92,
    );
    road(
      Path()
        ..moveTo(-80, 585)
        ..cubicTo(230, 550, 310, 640, 450, 620)
        ..cubicTo(635, 590, 730, 615, 980, 560),
      80,
    );
    road(
      Path()
        ..moveTo(140, 180)
        ..cubicTo(100, 360, 115, 780, 130, 1020)
        ..quadraticBezierTo(350, 1090, 730, 1010)
        ..cubicTo(795, 770, 770, 390, 740, 170)
        ..quadraticBezierTo(420, 105, 140, 180),
      43,
    );

    // A soft central plaza and a fountain give the player a clear landmark.
    oval(const Rect.fromLTWH(327, 493, 245, 245), const Color(0xFFF6F0D9));
    oval(const Rect.fromLTWH(374, 540, 151, 151), const Color(0xFFDAE8D8));
    oval(const Rect.fromLTWH(397, 563, 105, 105), _water);
    oval(const Rect.fromLTWH(418, 582, 40, 23), const Color(0xFFC6F8FA));

    // Decorative pond in the northeast corner.
    oval(const Rect.fromLTWH(635, 250, 205, 150), const Color(0xFF77C8D8));
    oval(const Rect.fromLTWH(659, 270, 142, 105), _water);

    // Building footprints and roof panels. Their labels identify the demo areas.
    _building(
      canvas,
      const Rect.fromLTWH(70, 58, 245, 120),
      'RECTORADO',
      const Color(0xFFE7BA7E),
    );
    _building(
      canvas,
      const Rect.fromLTWH(575, 65, 250, 120),
      'PABELLÓN',
      const Color(0xFF8DB9DC),
    );
    _building(
      canvas,
      const Rect.fromLTWH(210, 330, 150, 155),
      'AULARIO',
      const Color(0xFFF1A98D),
    );
    _building(
      canvas,
      const Rect.fromLTWH(545, 430, 150, 138),
      'BIBLIOTECA',
      const Color(0xFFB8A6E4),
    );
    _building(
      canvas,
      const Rect.fromLTWH(175, 805, 200, 150),
      'LABORATORIOS',
      const Color(0xFF8CCDBB),
    );
    _building(
      canvas,
      const Rect.fromLTWH(550, 820, 210, 150),
      'CAFETERÍA',
      const Color(0xFFF3C589),
    );

    // Tree crowns use layered circles rather than a pixel grid.
    const trees = <Offset>[
      Offset(45, 250),
      Offset(88, 310),
      Offset(48, 420),
      Offset(102, 710),
      Offset(72, 810),
      Offset(65, 1050),
      Offset(270, 235),
      Offset(330, 210),
      Offset(615, 225),
      Offset(835, 450),
      Offset(830, 700),
      Offset(790, 790),
      Offset(340, 745),
      Offset(270, 710),
      Offset(610, 720),
      Offset(720, 1080),
      Offset(300, 1060),
      Offset(540, 1090),
      Offset(155, 600),
      Offset(800, 570),
    ];
    for (var i = 0; i < trees.length; i++) {
      final center = trees[i];
      final radius = i.isEven ? 31.0 : 25.0;
      oval(
        Rect.fromCircle(center: center.translate(3, 7), radius: radius),
        const Color(0x33527B5A),
      );
      oval(
        Rect.fromCircle(center: center, radius: radius),
        const Color(0xFF5BAA78),
      );
      oval(
        Rect.fromCircle(
          center: center.translate(-7, -6),
          radius: radius * 0.55,
        ),
        const Color(0xFF86C997),
      );
    }

    // The fair is an identifiable destination near the south entrance.
    rounded(
      const Rect.fromLTWH(22, 1080, 300, 80),
      const Color(0xFFFFE8A7),
      28,
    );
    _label(
      canvas,
      'FERIA UNIVERSITARIA',
      const Rect.fromLTWH(27, 1095, 290, 50),
      22,
    );
    for (final x in const <double>[360, 430, 690, 770]) {
      rounded(Rect.fromLTWH(x, 1084, 54, 50), const Color(0xFFFA706A), 8);
      rounded(Rect.fromLTWH(x + 8, 1084, 13, 50), const Color(0xFFFFF4E7), 3);
      rounded(Rect.fromLTWH(x + 34, 1084, 13, 50), const Color(0xFFFFF4E7), 3);
    }
    canvas.restore();
  }

  static void _building(Canvas canvas, Rect rect, String label, Color roof) {
    final shadow = Paint()..color = const Color(0x33506C6B);
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    final roofPaint = Paint()..color = roof;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(7, 9)),
        const Radius.circular(19),
      ),
      shadow,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(19)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(8), const Radius.circular(13)),
      roofPaint,
    );
    _label(
      canvas,
      label,
      Rect.fromLTWH(rect.left + 8, rect.center.dy - 18, rect.width - 16, 36),
      17,
    );
  }

  static void _label(Canvas canvas, String text, Rect within, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _ink,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          fontFamily: AppTheme.fontFamily,
          letterSpacing: 0.7,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: within.width);
    painter.paint(
      canvas,
      Offset(
        within.center.dx - painter.width / 2,
        within.center.dy - painter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant PixelCampusPainter oldDelegate) => false;
}
