import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import 'pixel_frame_painter.dart';
import 'pixel_icon.dart';

/// Colors and metrics of one [PixelButtonVariant]. The bevel and slab tones are
/// derived from [face] and [outline], so only these three colors are needed.
@immutable
class PixelButtonStyle {
  const PixelButtonStyle({
    required this.face,
    required this.outline,
    required this.foreground,
    this.fontSize = 22,
    this.horizontalPadding = 20,
    this.iconGap = 12,
  });

  /// Fill of the button.
  final Color face;

  /// Stroke around the face and the slab below it.
  final Color outline;

  /// Label and icon color.
  final Color foreground;

  final double fontSize;
  final double horizontalPadding;

  /// Space between the icon (or spinner) and the label.
  final double iconGap;
}

/// The kinds of [PixelButton]. To restyle a kind, edit its
/// [PixelButtonStyle] below: every button of that kind updates.
enum PixelButtonVariant {
  /// Main action of a screen (e.g. start a capture).
  primary(
    PixelButtonStyle(
      face: Color.fromARGB(255, 213, 53, 71),
      outline: AppColors.onAccent,
      foreground: AppColors.surface,
    ),
  ),

  /// Secondary action; smaller so two fit side by side in a row.
  secondary(
    PixelButtonStyle(
      face: Color.fromARGB(255, 209, 232, 243),
      outline: AppColors.onAccent,
      foreground: AppColors.text,
      fontSize: 20,
      horizontalPadding: 11,
      iconGap: 7,
    ),
  ),

  /// White action (the classic map look). No screen uses it right now.
  neutral(
    PixelButtonStyle(
      face: AppColors.surface,
      outline: AppColors.onAccent,
      foreground: AppColors.text,
      fontSize: 20,
      horizontalPadding: 11,
      iconGap: 7,
    ),
  ),

  /// Neutral highlighted action (default).
  tertiary(
    PixelButtonStyle(
      face: AppColors.accent,
      outline: AppColors.onAccent,
      foreground: AppColors.text,
    ),
  ),

  /// Destructive action (e.g. log out).
  danger(
    PixelButtonStyle(
      face: AppColors.dangerFill,
      outline: AppColors.text,
      foreground: AppColors.surface,
    ),
  );

  const PixelButtonVariant(this.style);

  final PixelButtonStyle style;
}

/// Big, high-contrast pixel-art button (min height 56) with haptic feedback
/// and a loading state. Disabled when [onPressed] is null or [loading] is true.
///
/// The frame is drawn by [PixelFramePainter]; colors and sizes come from the
/// [variant]'s [PixelButtonStyle]. Use [PixelButton.primary], [.secondary],
/// [.tertiary], [.neutral] or [.danger] to pick the kind, or pass [variant]
/// directly.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PixelButtonVariant.tertiary,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.minHeight = AppTheme.minButtonHeight,
  });

  const PixelButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.minHeight = AppTheme.minButtonHeight,
  }) : variant = PixelButtonVariant.primary;

  const PixelButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.minHeight = AppTheme.minButtonHeight,
  }) : variant = PixelButtonVariant.secondary;

  const PixelButton.neutral({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.minHeight = AppTheme.minButtonHeight,
  }) : variant = PixelButtonVariant.neutral;

  const PixelButton.tertiary({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.minHeight = AppTheme.minButtonHeight,
  }) : variant = PixelButtonVariant.tertiary;

  const PixelButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.minHeight = AppTheme.minButtonHeight,
  }) : variant = PixelButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final PixelButtonVariant variant;
  final bool loading;
  final PixelIconData? icon;

  /// Fill the available width (default) or size to content.
  final bool expand;
  final double minHeight;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final style = widget.variant.style;
    final face = style.face;
    final foreground = style.foreground;

    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(foreground),
            ),
          )
        else if (widget.icon != null)
          PixelIcon(widget.icon!, color: foreground),
        if (widget.loading || widget.icon != null)
          SizedBox(width: style.iconGap),
        Flexible(
          child: Text(
            widget.label.toUpperCase(),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            // Family and weight come from the theme's labelLarge (pixel font).
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              letterSpacing: 0,
              fontSize: style.fontSize,
            ),
          ),
        ),
      ],
    );

    // The face sinks by one block when pressed; padding keeps the total
    // height constant so neighbors do not move.
    const block = PixelFramePainter.defaultPixel;
    final pressed = _enabled && _pressed;
    final horizontal = style.horizontalPadding;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: Opacity(
        opacity: _enabled ? 1 : 0.55,
        child: CustomPaint(
          painter: PixelFramePainter(
            face: face,
            outline: style.outline,
            highlight: Color.lerp(face, Colors.white, 0.5)!,
            shade: Color.lerp(face, style.outline, 0.3)!,
            pressed: pressed,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: _enabled ? _handleTap : null,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              // The frame itself is the press feedback; no ripple.
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: widget.minHeight,
                  minWidth: 48,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    12 + (pressed ? block : 0),
                    horizontal,
                    12 + (pressed ? 0 : block),
                  ),
                  child: Center(
                    widthFactor: widget.expand ? null : 1,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }
}
