import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import 'pixel_frame_painter.dart';

enum PixelButtonVariant { primary, secondary, danger }

/// Big, high-contrast pixel-art button (min height 56) with haptic feedback
/// and a loading state. Disabled when [onPressed] is null or [loading] is true.
///
/// The frame is drawn by [PixelFramePainter]; the face colors come from
/// [AppColors] and the bevel tones are derived from them.
class PixelButton extends StatefulWidget {
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

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final variant = widget.variant;
    final (Color face, Color foreground) = switch (variant) {
      PixelButtonVariant.primary => (AppColors.accent, AppColors.onAccent),
      PixelButtonVariant.secondary => (AppColors.surface, AppColors.text),
      PixelButtonVariant.danger => (AppColors.dangerFill, Colors.white),
    };
    final secondary = variant == PixelButtonVariant.secondary;

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
          Icon(widget.icon, color: foreground, size: secondary ? 20 : 24),
        if (widget.loading || widget.icon != null)
          SizedBox(width: secondary ? 7 : 12),
        Flexible(
          child: Text(
            widget.label.toUpperCase(),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            // Family and weight come from the theme's labelLarge (pixel font).
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              letterSpacing: 0,
              fontSize: secondary ? 20 : 22,
            ),
          ),
        ),
      ],
    );

    // The face sinks by one block when pressed; padding keeps the total
    // height constant so neighbors do not move.
    const block = PixelFramePainter.defaultPixel;
    final pressed = _enabled && _pressed;
    final horizontal = secondary ? 11.0 : 20.0;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: Opacity(
        opacity: _enabled ? 1 : 0.55,
        child: CustomPaint(
          painter: PixelFramePainter(
            face: face,
            outline: AppColors.text,
            highlight: Color.lerp(face, Colors.white, 0.5)!,
            shade: Color.lerp(face, AppColors.text, 0.3)!,
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
