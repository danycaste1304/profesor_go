import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/capture_ball.dart';

/// Original game wordmark with the capture ball as its emblem.
class PixelLogo extends StatelessWidget {
  const PixelLogo({
    super.key,
    this.fontSize = 36,
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
      fontFamily: AppTheme.fontFamily,
      fontFamilyFallback: AppTheme.fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: -fontSize / 35,
      height: 1.1,
    );
    return Semantics(
      header: true,
      label: 'Profesor GO',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBall) ...[
            const CaptureBall(size: 76),
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
            Text(
              tagline!.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontFamilyFallback: AppTheme.fontFamilyFallback,
                fontSize: (fontSize / 3).clamp(11.0, 16.0),
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
