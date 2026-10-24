import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/rarity.dart';
import 'pixel_pill.dart';

/// Pixel-art rarity chip: icon + Spanish label + color. Never color-only
/// (a11y). One component for grid cards (`compact`) and the detail / result /
/// encounter screens. A [PixelPill] filled with the rarity color, or tinted
/// (light face, rarity-colored frame and content) when [tinted] is set.
class RarityBadge extends StatelessWidget {
  const RarityBadge(
    this.rarity, {
    super.key,
    this.compact = false,
    this.tinted = false,
  });

  final Rarity rarity;

  /// Smaller padding / font / pixel blocks for list rows.
  final bool compact;

  /// Light rarity-tinted face instead of the solid one; used on collection and
  /// detail, where the badge sits on a card. Subject to
  /// [PixelPill.tintedStyleEnabled].
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    return PixelPill(
      label: rarity.label,
      icon: AppTheme.rarityIcon(rarity),
      color: AppTheme.rarityColor(rarity),
      tinted: tinted,
      compact: compact,
      semanticLabel: 'Rareza: ${rarity.label}',
    );
  }
}
