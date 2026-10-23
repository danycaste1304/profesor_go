import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/featured_professors.dart';

enum ProfessorSpritePose { portrait, fullBody }

/// Professor avatar: the remote sprite when available, otherwise a
/// deterministic blocky pixel "face" generated from the professor id.
/// [silhouette] renders a black shape with "???" for uncaptured professors.
class ProfessorSprite extends StatelessWidget {
  const ProfessorSprite({
    super.key,
    required this.professorId,
    this.spriteUrl,
    this.size = 96,
    this.silhouette = false,
    this.transparentBackground = false,
    this.semanticLabel,
    this.pose = ProfessorSpritePose.portrait,
  });

  final String professorId;
  final String? spriteUrl;
  final double size;
  final bool silhouette;
  final bool transparentBackground;
  final String? semanticLabel;
  final ProfessorSpritePose pose;

  @override
  Widget build(BuildContext context) {
    final generated = CustomPaint(
      size: Size.square(size),
      painter: PixelFacePainter(
        seed: professorId,
        silhouette: silhouette,
        transparentBackground: transparentBackground,
      ),
    );

    Widget child;
    final url = spriteUrl;
    final localAsset = switch (professorId) {
      danielRiofrioId =>
        pose == ProfessorSpritePose.fullBody
            ? danielRiofrioFullAsset
            : danielRiofrioPortraitAsset,
      erickNaunayId =>
        pose == ProfessorSpritePose.fullBody
            ? erickNaunayFullAsset
            : erickNaunayPortraitAsset,
      noelPerezId =>
        pose == ProfessorSpritePose.fullBody
            ? noelPerezFullAsset
            : noelPerezPortraitAsset,
      pavelAlbaId =>
        pose == ProfessorSpritePose.fullBody
            ? pavelAlbaFullAsset
            : pavelAlbaPortraitAsset,
      ricardoFloresId =>
        pose == ProfessorSpritePose.fullBody
            ? ricardoFloresFullAsset
            : ricardoFloresPortraitAsset,
      joseDavidVegaId =>
        pose == ProfessorSpritePose.fullBody
            ? joseDavidVegaFullAsset
            : joseDavidVegaPortraitAsset,
      felipeGrijalvaId =>
        pose == ProfessorSpritePose.fullBody
            ? felipeGrijalvaFullAsset
            : felipeGrijalvaPortraitAsset,
      henryCarvajalId =>
        pose == ProfessorSpritePose.fullBody
            ? henryCarvajalFullAsset
            : henryCarvajalPortraitAsset,
      diegoMoralesId =>
        pose == ProfessorSpritePose.fullBody
            ? diegoMoralesFullAsset
            : diegoMoralesPortraitAsset,
      robertoAndradeId =>
        pose == ProfessorSpritePose.fullBody
            ? robertoAndradeFullAsset
            : robertoAndradePortraitAsset,
      _ => null,
    };
    if (url != null && url.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        placeholder: (_, _) => generated,
        errorWidget: (_, _, _) => generated,
      );
    } else if (localAsset != null) {
      child = Image.asset(
        localAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) => generated,
      );
    } else {
      child = generated;
    }
    if (silhouette && (url != null && url.isNotEmpty || localAsset != null)) {
      child = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
        child: child,
      );
    }

    return Semantics(
      image: true,
      label:
          semanticLabel ?? (silhouette ? 'Profesor sin capturar' : 'Profesor'),
      child: SizedBox.square(
        dimension: size,
        child:
            silhouette && (url != null && url.isNotEmpty || localAsset != null)
            ? Stack(
                alignment: Alignment.center,
                children: [child, _questionMarks(size)],
              )
            : child,
      ),
    );
  }

  static Widget _questionMarks(double size) => Text(
    '???',
    style: TextStyle(
      color: AppColors.accent,
      fontSize: size * 0.28,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
    ),
  );
}

/// Draws an original 24 x 24 pixel professor portrait when no art is uploaded.
/// Skin, hair and jacket vary deterministically with [seed].
class PixelFacePainter extends CustomPainter {
  PixelFacePainter({
    required this.seed,
    this.silhouette = false,
    this.transparentBackground = false,
  });

  final String seed;
  final bool silhouette;
  final bool transparentBackground;

  static const _skinPalette = <Color>[
    Color(0xFFFFD8B5),
    Color(0xFFF1B68D),
    Color(0xFFD18C64),
    Color(0xFF9E654A),
    Color(0xFFF2C8A6),
  ];
  static const _hairPalette = <Color>[
    Color(0xFF382A31),
    Color(0xFF785036),
    Color(0xFFE5C374),
    Color(0xFF5F6575),
    Color(0xFF263D4B),
  ];
  static const _coatPalette = <Color>[
    Color(0xFF356FB1),
    Color(0xFF52A491),
    Color(0xFFB276A7),
    Color(0xFFE59561),
    Color(0xFF597A9B),
  ];
  static const _backPalette = <Color>[
    Color(0xFFD6EDFC),
    Color(0xFFDAF2D8),
    Color(0xFFFDE9C8),
    Color(0xFFE9E2FA),
    Color(0xFFF7DDE6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    // String.hashCode may change between app launches. Keep each professor's
    // generated portrait stable in the collection and on the battle screen.
    var stableSeed = 0x811c9dc5;
    for (final codeUnit in seed.codeUnits) {
      stableSeed = ((stableSeed ^ codeUnit) * 0x01000193) & 0xffffffff;
    }
    final rng = Random(stableSeed);
    final skin = _skinPalette[rng.nextInt(_skinPalette.length)];
    final hair = _hairPalette[rng.nextInt(_hairPalette.length)];
    final coat = _coatPalette[rng.nextInt(_coatPalette.length)];
    final back = _backPalette[rng.nextInt(_backPalette.length)];
    final hasGlasses = rng.nextBool();
    final hasBeard = rng.nextInt(4) == 0;
    final paint = Paint()..isAntiAlias = false;
    void px(int x, int y, int w, int h, Color color) {
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
        paint,
      );
    }

    if (!transparentBackground) {
      px(1, 1, 22, 22, silhouette ? const Color(0xFFD8E4E8) : back);
      px(3, 22, 18, 1, const Color(0x44506C73));
    }
    const outline = Color(0xFF263C52);
    final body = silhouette ? const Color(0xFF405262) : coat;
    final face = silhouette ? const Color(0xFF405262) : skin;
    final hairColor = silhouette ? const Color(0xFF405262) : hair;
    px(4, 16, 16, 7, outline);
    px(5, 17, 14, 6, body);
    px(3, 18, 2, 5, body);
    px(19, 18, 2, 5, body);
    px(10, 14, 4, 4, face);
    px(6, 5, 12, 11, outline);
    px(7, 6, 10, 10, face);
    px(6, 7, 2, 8, hairColor);
    px(16, 7, 2, 8, hairColor);
    px(7, 4, 10, 4, hairColor);
    px(8, 3, 8, 2, hairColor);
    px(6, 6, 3, 3, hairColor);
    px(15, 6, 3, 3, hairColor);
    if (!silhouette) {
      px(9, 10, 1, 1, outline);
      px(14, 10, 1, 1, outline);
      px(10, 13, 4, 1, const Color(0xFF94584B));
      px(9, 17, 6, 5, const Color(0xFFF7FAFC));
      px(11, 17, 2, 5, hair);
      px(5, 19, 3, 1, const Color(0xFFFFFFFF));
      if (hasGlasses) {
        px(8, 9, 3, 1, outline);
        px(13, 9, 3, 1, outline);
        px(8, 10, 1, 2, outline);
        px(10, 10, 1, 2, outline);
        px(13, 10, 1, 2, outline);
        px(15, 10, 1, 2, outline);
        px(11, 9, 2, 1, outline);
      }
      if (hasBeard) px(9, 14, 6, 2, hair);
    } else {
      final label = TextPainter(
        text: const TextSpan(
          text: '???',
          style: TextStyle(
            color: Colors.white,
            fontSize: 6,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(12 - label.width / 2, 11 - label.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PixelFacePainter old) =>
      old.seed != seed ||
      old.silhouette != silhouette ||
      old.transparentBackground != transparentBackground;
}
