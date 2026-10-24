import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/collection_progress.dart';
import '../../../core/models/rarity.dart';
import '../../../core/widgets/widgets.dart';

/// Subtle strip shown when the screen renders last-known (cached) data.
class CachedDataBanner extends StatelessWidget {
  const CachedDataBanner({super.key});

  static const text = 'Mostrando datos guardados';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border(bottom: BorderSide(color: AppColors.border, width: 2)),
        ),
        child: Row(
          children: [
            const PixelIcon(PixelIcons.cloudOff, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header card: global "captured / total" bar + one mini bar per rarity.
class CollectionHeader extends StatelessWidget {
  const CollectionHeader({
    super.key,
    required this.progress,
    required this.byRarity,
  });

  final CollectionProgress progress;
  final Map<Rarity, RarityProgress> byRarity;

  @override
  Widget build(BuildContext context) {
    return PixelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProgressBar(
            value: progress.captured,
            total: progress.total,
            label: 'PROFES CAPTURADOS',
            color: progress.completed ? AppColors.success : AppColors.accent,
          ),
          const SizedBox(height: 14),
          for (final rarity in Rarity.values) ...[
            RarityMiniBar(progress: byRarity[rarity]!),
            if (rarity != Rarity.values.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// One row: rarity icon + label, a thin bar and the `captured/total` count.
class RarityMiniBar extends StatelessWidget {
  const RarityMiniBar({super.key, required this.progress});

  final RarityProgress progress;

  @override
  Widget build(BuildContext context) {
    final rarity = progress.rarity;
    final color = AppTheme.rarityColor(rarity);
    final labelStyle = TextStyle(color: color, fontSize: 18, letterSpacing: 0);
    return Semantics(
      label: '${rarity.label}: ${progress.captured} de ${progress.total}',
      excludeSemantics: true,
      child: Row(
        children: [
          PixelIcon(AppTheme.rarityIcon(rarity), color: color),
          const SizedBox(width: 6),
          SizedBox(
            width: 96,
            child: Text(
              rarity.label.toUpperCase(),
              style: labelStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ProgressBar(
              value: progress.captured,
              total: progress.total,
              color: color,
              height: 12,
              showPercent: false,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              '${progress.captured}/${progress.total}',
              textAlign: TextAlign.right,
              style: labelStyle.copyWith(color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pixel-art button for the rarity filter row. `rarity == null` means "Todos".
/// The selected filter reads as pressed in (sunken) and tinted with its color.
class RarityFilterChip extends StatelessWidget {
  const RarityFilterChip({
    super.key,
    required this.rarity,
    required this.selected,
    required this.onSelected,
  });

  final Rarity? rarity;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final r = rarity;
    final color = r == null ? AppColors.accent : AppTheme.rarityColor(r);
    final label = (r?.label ?? 'Todos').toUpperCase();
    // Accent yellow is too light for text on white; use its darker text tone.
    final textColor = r == null ? AppColors.accentText : color;
    final face = selected
        ? Color.alphaBlend(color.withValues(alpha: 0.22), AppColors.surface)
        : AppColors.surface;
    const block = PixelFramePainter.defaultPixel;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filtro: ${r?.label ?? 'Todos'}',
      excludeSemantics: true,
      child: CustomPaint(
        painter: PixelFramePainter(
          face: face,
          outline: AppColors.text,
          highlight: Color.lerp(face, Colors.white, 0.5)!,
          shade: Color.lerp(face, AppColors.text, 0.3)!,
          pressed: selected,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onSelected,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Padding(
                // Keeps the content centered in the face, not in the slab.
                padding: EdgeInsets.fromLTRB(
                  14,
                  selected ? block : 0,
                  14,
                  selected ? 0 : block,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PixelIcon(
                      r == null ? PixelIcons.grid : AppTheme.rarityIcon(r),
                      color: selected ? textColor : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? textColor : AppColors.text,
                        fontFamily: AppTheme.bodyFontFamily,
                        fontSize: 18,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
