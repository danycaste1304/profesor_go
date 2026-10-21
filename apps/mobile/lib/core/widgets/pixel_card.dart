import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Framed panel with a crisp shadow inspired by portable RPGs.
class PixelCard extends StatelessWidget {
  const PixelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.onTap,
    this.shadow = true,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool shadow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? AppColors.border;
    final content = Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: border, width: AppTheme.borderWidth),
        boxShadow: shadow
            ? const [BoxShadow(color: AppColors.shadow, offset: Offset(3, 3))]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    final wrapped = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: content,
            ),
          );

    if (semanticLabel == null) return wrapped;
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: wrapped,
    );
  }
}
