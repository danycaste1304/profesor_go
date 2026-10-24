import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/pixel_card.dart';
import '../../../../core/widgets/pixel_icon.dart';
import '../../../../core/widgets/pixel_icons.dart';

enum AuthBannerKind { error, info }

/// Inline banner for auth screens: red border for errors, cyan for info.
/// Announced to screen readers as a live region.
class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    super.key,
    required this.message,
    this.kind = AuthBannerKind.error,
    this.onDismiss,
  });

  final String message;
  final AuthBannerKind kind;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final (Color color, PixelIconData icon) = switch (kind) {
      AuthBannerKind.error => (AppColors.danger, PixelIcons.error),
      AuthBannerKind.info => (AppColors.accentAlt, PixelIcons.info),
    };
    return Semantics(
      liveRegion: true,
      child: PixelCard(
        borderColor: color,
        color: color.withValues(alpha: 0.12),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            PixelIcon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                tooltip: 'Cerrar',
                icon: const PixelIcon(PixelIcons.close),
                iconSize: 22,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
          ],
        ),
      ),
    );
  }
}
