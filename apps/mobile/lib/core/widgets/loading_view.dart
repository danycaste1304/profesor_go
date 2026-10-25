import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme.dart';
import 'capture_ball.dart';

/// Centered spinning capture ball with an optional message.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message, this.size = 72});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CaptureBall(size: size)
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 1200.ms, curve: Curves.linear),
          if (message != null) ...[
            const SizedBox(height: 20),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
