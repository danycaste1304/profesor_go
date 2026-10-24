import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../errors/app_exception.dart';
import 'pixel_button.dart';
import 'pixel_icon.dart';
import 'pixel_icons.dart';

/// Friendly error message with an optional retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Reintentar',
    this.retryIcon = PixelIcons.refresh,
    this.retryVariant = PixelButtonVariant.tertiary,
    this.icon = PixelIcons.error,
  });

  /// Maps any error to its Spanish user message (never shows stack traces).
  ErrorView.fromError(
    Object error, {
    super.key,
    this.onRetry,
    this.retryLabel = 'Reintentar',
    this.retryIcon = PixelIcons.refresh,
    this.retryVariant = PixelButtonVariant.tertiary,
    this.icon = PixelIcons.error,
  }) : message = AppException.from(error).message;

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final PixelIconData retryIcon;
  final PixelButtonVariant retryVariant;
  final PixelIconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelIcon(icon, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              PixelButton(
                label: retryLabel,
                onPressed: onRetry,
                icon: retryIcon,
                variant: retryVariant,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
