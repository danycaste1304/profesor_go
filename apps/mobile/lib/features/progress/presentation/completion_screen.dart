import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../collection/domain/date_format.dart';

/// `/completion` — celebration and an in-app achievement for a full collection.
class CompletionScreen extends ConsumerStatefulWidget {
  const CompletionScreen({super.key});

  static const title = '¡Profedex completada!';
  static const achievementTitle = 'Maestro del campus';

  @override
  ConsumerState<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends ConsumerState<CompletionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti;
  late final List<ConfettiParticle> _particles;

  DateTime? _completedAt;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _particles = ConfettiParticle.generate(70, Random(20260916));
    _loadCompletedAt();
  }

  Future<void> _loadCompletedAt() async {
    DateTime? fromProfile;
    try {
      final profile = await ref.read(authRepositoryProvider).getProfile();
      fromProfile = profile?.collectionCompletedAt;
    } catch (_) {
      // The achievement remains visible when profile metadata is unavailable.
    }
    if (!mounted || fromProfile == null) return;
    setState(() => _completedAt = fromProfile);
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(collectionProgressProvider);
    if (progressAsync.isLoading) {
      return const AppScaffold(
        title: 'Logro',
        homeFallback: true,
        body: LoadingView(message: 'Comprobando tu Profedex…'),
      );
    }
    if (progressAsync.hasError) {
      return AppScaffold(
        title: 'Logro',
        homeFallback: true,
        body: ErrorView.fromError(
          progressAsync.error!,
          onRetry: () => ref.invalidate(collectionProgressProvider),
        ),
      );
    }
    final progress = progressAsync.value!;
    if (!progress.completed) {
      return AppScaffold(
        title: 'Logro',
        homeFallback: true,
        body: Center(
          child: PixelCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 14),
                Text(
                  'Aún quedan profesores por descubrir',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                ProgressBar(
                  value: progress.captured,
                  total: progress.total,
                  label: 'Tu Profedex',
                ),
              ],
            ),
          ),
        ),
        bottomBar: PixelButton(
          label: 'Ver Profedex',
          icon: Icons.menu_book,
          onPressed: () => context.go(AppRoutes.collection),
        ),
      );
    }
    final captured = progress.captured;
    final total = progress.total;

    return AppScaffold(
      showAppBar: false,
      padding: EdgeInsets.zero,
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelButton(
            label: 'Volver al mapa',
            icon: Icons.map,
            onPressed: () => context.go(AppRoutes.map),
          ),
          const SizedBox(height: 10),
          PixelButton(
            label: 'Ver mi Profedex',
            icon: Icons.menu_book,
            variant: PixelButtonVariant.secondary,
            onPressed: () => context.go(AppRoutes.collection),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ConfettiPainter(
                  animation: _confetti,
                  particles: _particles,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _EmojiRow(),
                const SizedBox(height: 16),
                Text(
                      CompletionScreen.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.accentText,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    )
                    .then()
                    .shimmer(duration: 1200.ms, color: AppColors.accentAlt),
                const SizedBox(height: 8),
                Text(
                  'Has descubierto a todos los profesores de la feria.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                PixelCard(
                      borderColor: AppColors.success,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _InfoRow(
                            icon: Icons.event_available,
                            label: 'Completada el',
                            value: _completedAt == null
                                ? 'Fecha no disponible'
                                : formatDateTime(_completedAt!),
                          ),
                          const SizedBox(height: 12),
                          ProgressBar(
                            value: captured,
                            total: total,
                            label: 'Profesores capturados',
                            color: AppColors.success,
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms)
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      delay: 300.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const SizedBox(height: 20),
                const _AchievementSection()
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 400.ms)
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      delay: 600.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouncing emoji "blocks" (no external assets).
class _EmojiRow extends StatelessWidget {
  const _EmojiRow();

  static const _emojis = ['🎓', '🏆', '🎉'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _emojis.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child:
                PixelCard(
                      padding: const EdgeInsets.all(10),
                      color: AppColors.surfaceAlt,
                      borderColor: i == 1 ? AppColors.accent : AppColors.border,
                      child: Text(
                        _emojis[i],
                        style: const TextStyle(fontSize: 36),
                      ),
                    )
                    .animate(
                      onPlay: (c) => c.repeat(reverse: true),
                      delay: (i * 150).ms,
                    )
                    .moveY(
                      begin: 0,
                      end: -10,
                      duration: 650.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.success, size: 22),
        const SizedBox(width: 10),
        // Wrap: the value drops to its own line on narrow screens.
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 2,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              Text(value, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

/// A visible achievement earned by completing the active collection.
class _AchievementSection extends StatelessWidget {
  const _AchievementSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PixelCard(
      borderColor: AppColors.accent,
      color: AppColors.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'LOGRO DESBLOQUEADO',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.accentText,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Semantics(
              label: 'Medalla ${CompletionScreen.achievementTitle}',
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFEA94), AppColors.accent],
                  ),
                  border: Border.all(color: AppColors.accentText, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 68,
                  color: AppColors.accentText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            CompletionScreen.achievementTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Descubriste a todos los profesores activos de la feria.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One falling pixel-confetti square. Positions are normalized (0..1).
class ConfettiParticle {
  const ConfettiParticle({
    required this.x,
    required this.phase,
    required this.speed,
    required this.size,
    required this.sway,
    required this.color,
    required this.flat,
  });

  final double x;
  final double phase;

  /// Whole number of falls per animation loop, so the loop is seamless.
  final int speed;
  final double size;
  final double sway;
  final Color color;

  /// Flat rectangles alternate with squares for a paper-confetti look.
  final bool flat;

  static const palette = <Color>[
    AppColors.accent,
    AppColors.accentAlt,
    AppColors.success,
    AppColors.danger,
    AppColors.rarityRare,
    AppColors.rarityEpic,
    AppColors.rarityLegendary,
  ];

  static List<ConfettiParticle> generate(int count, Random random) => [
    for (var i = 0; i < count; i++)
      ConfettiParticle(
        x: random.nextDouble(),
        phase: random.nextDouble(),
        speed: 1 + random.nextInt(3),
        size: 5 + random.nextDouble() * 6,
        sway: 6 + random.nextDouble() * 18,
        color: palette[random.nextInt(palette.length)],
        flat: random.nextBool(),
      ),
  ];
}

/// Draws [particles] falling and swaying; repaints from [animation].
class ConfettiPainter extends CustomPainter {
  ConfettiPainter({required this.animation, required this.particles})
    : super(repaint: animation);

  final Animation<double> animation;
  final List<ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final fall = (p.phase + t * p.speed) % 1.0;
      final y = fall * (size.height + p.size * 2) - p.size;
      final x =
          p.x * size.width + sin((t * p.speed + p.phase) * 4 * pi) * p.sway;
      paint.color = p.color;
      final h = p.flat ? p.size * 0.5 : p.size;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: p.size, height: h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter old) =>
      old.particles != particles || old.animation != animation;
}
