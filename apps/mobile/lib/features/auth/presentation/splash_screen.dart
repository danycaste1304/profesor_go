import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/capture_ball.dart';
import 'widgets/pixel_logo.dart';

/// Boot screen: plays a short intro while [authStateProvider] resolves. The
/// router guard redirects to `/login` or `/map` on its own; as a safety net,
/// after [fallbackDelay] the screen navigates itself based on the current
/// session (e.g. if the auth stream never emits).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const Duration fallbackDelay = Duration(seconds: 3);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    _fallback = Timer(SplashScreen.fallbackDelay, _goFallback);
  }

  @override
  void dispose() {
    _fallback?.cancel();
    super.dispose();
  }

  void _goFallback() {
    if (!mounted) return;
    final user =
        ref.read(currentUserProvider) ??
        ref.read(authRepositoryProvider).currentUser;
    context.go(user == null ? AppRoutes.login : AppRoutes.map);
  }

  @override
  Widget build(BuildContext context) {
    // Watching keeps the auth stream alive so the router guard can resolve.
    final auth = ref.watch(authStateProvider);
    final status = auth.isLoading ? 'Cargando...' : 'Listo';

    return AppScaffold(
      showAppBar: false,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CaptureBall(size: 112)
                .animate()
                .slideY(
                  begin: -1.2,
                  end: 0,
                  duration: 700.ms,
                  curve: Curves.bounceOut,
                )
                .fadeIn(duration: 250.ms),
            const SizedBox(height: 28),
            // Per-effect delays run on the animation timeline; the widget-level
            // `Animate.delay` would leave a Timer pending if the router
            // redirects before it fires.
            const PixelLogo(
                  fontSize: 40,
                  tagline: 'Captura a los profes de la feria',
                  showBall: false,
                )
                .animate()
                .fadeIn(delay: 350.ms, duration: 400.ms)
                .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 40),
            Text(
                  status.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: AppColors.textMuted, letterSpacing: 3),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 0.25, end: 1, duration: 650.ms),
            if (AppConfig.isDemoMode) ...[
              const SizedBox(height: 12),
              const Text(
                'MODO DEMO',
                style: TextStyle(
                  color: AppColors.accentAlt,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(delay: 900.ms, duration: 300.ms),
            ],
          ],
        ),
      ),
    );
  }
}
