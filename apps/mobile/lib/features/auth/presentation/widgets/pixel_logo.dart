import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/capture_ball.dart';

/// Original game wordmark with the capture ball as its emblem.
class PixelLogo extends StatelessWidget {
  const PixelLogo({
    super.key,
    this.fontSize = 40,
    this.tagline,
    this.showBall = true,
  });

  final double fontSize;
  final bool showBall;

  /// Optional short line under the wordmark.
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: AppTheme.displayFontFamily,
      fontFamilyFallback: AppTheme.fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.1,
    );
    return Semantics(
      header: true,
      label: 'Profesor GO',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBall) ...[
            const CaptureBall(size: 84),
            const SizedBox(height: 12),
          ],
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Profesor ',
                  style: base.copyWith(color: AppColors.text),
                ),
                TextSpan(
                  text: 'GO',
                  style: base.copyWith(color: AppColors.accentAlt),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          if (tagline != null) ...[
            SizedBox(height: fontSize / 4),
            // Same style as the rest of the body text, just muted.
            Text(
              tagline!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
