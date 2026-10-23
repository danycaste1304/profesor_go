import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'pixel_bar_painter.dart';

/// Labelled, animated `value / total` pixel-art bar. Shows only the percentage
/// by default (the count is opt-in); the fill advances in whole pixel blocks.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    required this.total,
    this.label,
    this.color,
    this.height = 22,
    this.showCount = false,
    this.showPercent = true,
    this.duration = const Duration(milliseconds: 600),
  });

  final int value;
  final int total;
  final String? label;
  final Color? color;
  final double height;
  final bool showCount;

  /// Shows the rounded percentage next to (or instead of) the count.
  final bool showPercent;
  final Duration duration;

  double get _ratio => total <= 0 ? 0 : (value / total).clamp(0.0, 1.0);

  /// `3 / 10`, `30 %` or `3 / 10 · 30 %` depending on the flags.
  String get _trailing => [
    if (showCount) '$value / $total',
    if (showPercent) '${(_ratio * 100).round()} %',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final fill = color ?? AppColors.accent;
    final textStyle = Theme.of(context).textTheme.labelLarge;
    return Semantics(
      label: '${label ?? 'Progreso'}: $value de $total',
      value: '${(_ratio * 100).round()}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null || showCount || showPercent)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              // spaceBetween pins the percentage to the right edge whatever the
              // label's width; both shrink (ellipsis / scale down) when tight.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (label != null)
                    Flexible(
                      child: Text(
                        label!,
                        style: textStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (showCount || showPercent)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(_trailing, style: textStyle),
                      ),
                    ),
                ],
              ),
            ),
          SizedBox(
            height: height,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _ratio),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, ratio, _) => CustomPaint(
                painter: PixelBarPainter(
                  ratio: ratio,
                  track: AppColors.surfaceAlt,
                  fill: fill,
                  outline: AppColors.text,
                  // Thinner blocks keep slim bars (mini bars) readable.
                  pixel: height >= 20 ? 4 : 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
