import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/rarity.dart';

/// Rarity chip: icon + Spanish label + color. Never color-only (a11y).
class RarityBadge extends StatelessWidget {
  const RarityBadge(this.rarity, {super.key, this.compact = false});

  final Rarity rarity;

  /// Smaller padding / font for list rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.rarityColor(rarity);
    final fontSize = compact ? 12.0 : 14.0;
    return Semantics(
      label: 'Rareza: ${rarity.label}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppTheme.rarityIcon(rarity), size: fontSize + 4, color: color),
            const SizedBox(width: 6),
            Text(
              rarity.label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
