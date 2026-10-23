import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/rarity.dart';
import 'pixel_frame_painter.dart';

/// Pixel-art rarity chip: icon + Spanish label + color. Never color-only
/// (a11y). One component for grid cards (`compact`) and the detail / result /
/// encounter screens. Flat frame (no shadow), tinted with the rarity color.
class RarityBadge extends StatelessWidget {
  const RarityBadge(this.rarity, {super.key, this.compact = false});

  final Rarity rarity;

  /// Smaller padding / font / pixel blocks for list rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.rarityColor(rarity);
    // Thinner blocks than buttons: a 4 px frame would swallow a small chip.
    final block = compact ? 2.0 : 3.0;
    final fontSize = compact ? 16.0 : 20.0;
    return Semantics(
      label: 'Rareza: ${rarity.label}',
      child: CustomPaint(
        painter: PixelFramePainter.flat(
          // The frame needs an opaque face: tint over the card surface.
          face: Color.alphaBlend(color.withValues(alpha: 0.18), AppColors.surface),
          outline: color,
          pixel: block,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: (compact ? 6 : 9) + block,
            vertical: (compact ? 1 : 2) + block,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppTheme.rarityIcon(rarity), size: fontSize, color: color),
              const SizedBox(width: 6),
              Text(
                rarity.label.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontFamily: AppTheme.bodyFontFamily,
                  fontSize: fontSize,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
