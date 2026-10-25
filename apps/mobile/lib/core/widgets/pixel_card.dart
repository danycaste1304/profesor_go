import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'pixel_frame_painter.dart';

/// Pixel-art framed panel (stepped corners, no shadow). The outline is drawn
/// by [PixelFramePainter.flat]; pass [borderColor] to tint it.
class PixelCard extends StatelessWidget {
  const PixelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // The outline is painted inside the bounds, so content is inset by it.
    final content = Padding(
      padding: padding.add(
        const EdgeInsets.all(PixelFramePainter.defaultPixel),
      ),
      child: child,
    );

    final framed = CustomPaint(
      painter: PixelFramePainter.flat(
        face: color ?? AppColors.surface,
        outline: borderColor ?? AppColors.text,
      ),
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, child: content),
            ),
    );

    if (semanticLabel == null) return framed;
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: framed,
    );
  }
}
