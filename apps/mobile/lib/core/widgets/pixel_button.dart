import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

enum PixelButtonVariant { primary, secondary, danger }

/// Big, high-contrast button (min height 56) with haptic feedback and a
/// loading state. Disabled when [onPressed] is null or [loading] is true.
class PixelButton extends StatelessWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PixelButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.minHeight = AppTheme.minButtonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final PixelButtonVariant variant;
  final bool loading;
  final IconData? icon;

  /// Fill the available width (default) or size to content.
  final bool expand;
  final double minHeight;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final (
      Color background,
      Color foreground,
      Color border,
    ) = switch (variant) {
      PixelButtonVariant.primary => (
        AppColors.accent,
        AppColors.onAccent,
        AppColors.accent,
      ),
      PixelButtonVariant.secondary => (
        AppColors.surface,
        AppColors.text,
        AppColors.border,
      ),
      PixelButtonVariant.danger => (
        AppColors.dangerFill,
        Colors.white,
        AppColors.dangerFill,
      ),
    };

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(foreground),
            ),
          )
        else if (icon != null)
          Icon(
            icon,
            color: foreground,
            size: variant == PixelButtonVariant.secondary ? 20 : 24,
          ),
        if (loading || icon != null)
          SizedBox(width: variant == PixelButtonVariant.secondary ? 7 : 12),
        Flexible(
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              fontSize: variant == PixelButtonVariant.secondary ? 13 : 16,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: Opacity(
        opacity: _enabled ? 1 : 0.55,
        child: Material(
          color: background,
          shadowColor: AppColors.shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: BorderSide(color: border, width: AppTheme.borderWidth),
          ),
          child: InkWell(
            onTap: _enabled ? _handleTap : null,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight, minWidth: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: variant == PixelButtonVariant.secondary ? 11 : 20,
                  vertical: 12,
                ),
                child: Center(widthFactor: expand ? null : 1, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    onPressed?.call();
  }
}
