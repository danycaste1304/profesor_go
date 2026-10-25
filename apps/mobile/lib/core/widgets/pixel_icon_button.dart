import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'pixel_button.dart';
import 'pixel_circle_painter.dart';
import 'pixel_frame_painter.dart';
import 'pixel_icon.dart';

/// Circular pixel-art icon button with no visible label (music, help, ...).
///
/// Same look as [PixelButton]: outline, bevel, solid slab, and it sinks when
/// pressed. Because there is no text, [semanticLabel] is required. Pass
/// [toggled] for on/off buttons: `true` paints the tertiary face, `false` the
/// plain surface, and `null` (default) means it is not a toggle. Disabled when
/// [onPressed] is null.
class PixelIconButton extends StatefulWidget {
  const PixelIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.toggled,
    this.size = minSize,
  });

  /// Minimum touch target.
  static const double minSize = 48;

  final PixelIconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool? toggled;

  /// Total square size, including the block reserved for the slab.
  final double size;

  @override
  State<PixelIconButton> createState() => _PixelIconButtonState();
}

class _PixelIconButtonState extends State<PixelIconButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final on = widget.toggled ?? false;
    // The "on" look comes from the tertiary PixelButton variant, so restyling
    // that variant restyles every toggled icon button too.
    final onStyle = PixelButtonVariant.tertiary.style;
    final face = on ? onStyle.face : AppColors.surface;
    final foreground = on ? onStyle.foreground : AppColors.text;

    // The face sinks by one block when pressed; padding keeps the icon
    // centered on it.
    const block = PixelFramePainter.defaultPixel;
    final pressed = _enabled && _pressed;

    return Semantics(
      button: true,
      toggled: widget.toggled,
      enabled: _enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: Opacity(
        opacity: _enabled ? 1 : 0.55,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: PixelCirclePainter(
              face: face,
              outline: AppColors.text,
              highlight: Color.lerp(face, Colors.white, 0.5)!,
              shade: Color.lerp(face, AppColors.text, 0.3)!,
              pressed: pressed,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _enabled ? widget.onPressed : null,
                onHighlightChanged: (value) => setState(() => _pressed = value),
                customBorder: const CircleBorder(),
                // The frame itself is the press feedback; no ripple.
                splashFactory: NoSplash.splashFactory,
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: pressed ? block : 0,
                    bottom: pressed ? 0 : block,
                  ),
                  child: Center(
                    child: PixelIcon(widget.icon, color: foreground),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
