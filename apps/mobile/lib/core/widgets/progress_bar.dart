import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Labelled, animated `value / total` bar with a pixel border.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    required this.total,
    this.label,
    this.color,
    this.height = 22,
    this.showCount = true,
    this.duration = const Duration(milliseconds: 600),
  });

  final int value;
  final int total;
  final String? label;
  final Color? color;
  final double height;
  final bool showCount;
  final Duration duration;

  double get _ratio => total <= 0 ? 0 : (value / total).clamp(0.0, 1.0);

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
          if (label != null || showCount)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  if (label != null)
                    Expanded(child: Text(label!, style: textStyle)),
                  if (showCount)
                    Text('$value / $total', style: textStyle),
                ],
              ),
            ),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border.all(color: AppColors.border, width: 2),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            clipBehavior: Clip.hardEdge,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _ratio),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, ratio, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: fill),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
