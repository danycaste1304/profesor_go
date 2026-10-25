import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'pixel_frame_painter.dart';
import 'pixel_icon.dart';

/// Pixel-art pill: optional icon + uppercase label on a [color] face, framed like
/// [PixelCard] and [PixelButton] (stepped corners, no shadow). Solid by
/// default: the frame is the same [color] as the face and the content is
/// white. A [tinted] pill gets a light face with [color] on the frame, icon and
/// label instead.
///
/// Never color-only (a11y): the label always carries the meaning; the icon is
/// optional decoration on top of it.
/// Base of [RarityBadge] and of the map's location / connection pills.
class PixelPill extends StatelessWidget {
  const PixelPill({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    this.tinted = false,
    this.tintOpacity = defaultTintOpacity,
    this.compact = false,
    this.scale = 1,
    this.foreground,
    this.semanticLabel,
  });

  /// Default face opacity of the tinted variant over the card surface.
  static const double defaultTintOpacity = 0.05;

  /// Style switch for comparing looks: `true` honors [tinted]; `false` renders
  /// every pill solid, in the map and in [RarityBadge] alike.
  static const bool tintedStyleEnabled = true;

  final String label;

  /// Glyph before the label; the pill is text-only when `null`.
  final PixelIconData? icon;

  /// Face color in the solid variant; frame, icon and label color in the
  /// tinted one.
  final Color color;

  /// Light [color]-tinted face instead of the solid one. Ignored while
  /// [tintedStyleEnabled] is `false`.
  final bool tinted;

  /// Opacity of the [color] face when tinted, from 0 (just the card surface)
  /// to 1 (solid).
  final double tintOpacity;

  /// Smaller padding / font / pixel blocks for list rows.
  final bool compact;

  /// Multiplies every metric (frame blocks, font, padding, icon, gap) on top
  /// of [compact]. Whole numbers (1, 2, 3...) keep the pixel blocks crisp.
  final double scale;

  /// Label and icon color. Defaults to white on a solid face (and [color] on a
  /// tinted one); set it for light faces such as yellow, where white is
  /// unreadable.
  final Color? foreground;

  /// Overrides [label] for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isTinted = tintedStyleEnabled && tinted;
    final foreground =
        this.foreground ?? (isTinted ? color : AppColors.surface);
    // Thinner blocks than buttons: a 4 px frame would swallow a small chip.
    final block = (compact ? 2.5 : 3.0) * scale;
    final fontSize = (compact ? 16.0 : 20.0) * scale;
    final pill = CustomPaint(
      painter: PixelFramePainter.flat(
        // The frame needs an opaque face: tint over the card surface.
        face: isTinted
            ? Color.alphaBlend(
                color.withValues(alpha: tintOpacity),
                AppColors.surface,
              )
            : color,
        // Same color as the solid face, so the frame only shapes the corners.
        outline: color,
        pixel: block,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: (compact ? 6 : 9) * scale + block,
          vertical: (compact ? 1 : 2) * scale + block,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              // PixelIcon has a fixed glyph size; FittedBox scales it to match.
              SizedBox.square(
                dimension: icon!.extent * scale,
                child: FittedBox(child: PixelIcon(icon!, color: foreground)),
              ),
              SizedBox(width: 6 * scale),
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: foreground,
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: fontSize,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );

    if (semanticLabel == null) return pill;
    return Semantics(label: semanticLabel, child: pill);
  }
}
