import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/audio/scene_music.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/capture_result_args.dart';

/// `/result` — outcome of the throw (typed `extra`: [CaptureResultArgs]).
class CaptureResultScreen extends ConsumerStatefulWidget {
  const CaptureResultScreen({super.key, required this.args});

  /// From the `/result` route `extra`.
  final CaptureResultArgs args;

  @override
  ConsumerState<CaptureResultScreen> createState() =>
      _CaptureResultScreenState();
}

class _CaptureResultScreenState extends ConsumerState<CaptureResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.args.success) {
      // The collection changed: refresh professors / captures / progress.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) invalidateCollection(ref);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final page = AppScaffold(
      title: args.success ? '¡Capturado!' : 'Se escapó',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: args.success
              ? _SuccessBody(args: args)
              : _FailureBody(args: args),
        ),
      ),
      bottomBar: args.success
          ? _SuccessActions(args: args)
          : const _FailureActions(),
    );
    return args.success
        ? SceneMusic(cue: SceneMusicCue.victory, child: page)
        : page;
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.args});

  final CaptureResultArgs args;

  @override
  Widget build(BuildContext context) {
    final professor = args.professor;
    final textTheme = Theme.of(context).textTheme;
    final rarityColor = AppTheme.rarityColor(professor.rarity);
    final collection = args.collection;
    final quality = args.quality;

    return Column(
      children: [
        RetroDialogue(
          text: '¡${professor.displayName} se unió a tu Profedex!',
          minHeight: 42,
        ),
        const SizedBox(height: 20),
        PixelCard(
          borderColor: rarityColor,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ProfessorSprite(
                    professorId: professor.id,
                    spriteUrl: professor.spriteUrl,
                    size: 160,
                    semanticLabel: professor.displayName,
                  )
                  .animate()
                  .scale(
                    begin: const Offset(0.4, 0.4),
                    end: const Offset(1, 1),
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                  )
                  .then()
                  .shimmer(
                    duration: 900.ms,
                    color: rarityColor.withValues(alpha: 0.5),
                  ),
              const SizedBox(height: 14),
              Text(professor.displayName, style: textTheme.titleLarge),
              const SizedBox(height: 8),
              RarityBadge(professor.rarity),
              if (quality != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Lanzamiento: ${quality.label}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              if (professor.description != null &&
                  professor.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  professor.description!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        if (collection != null) ...[
          const SizedBox(height: 20),
          PixelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProgressBar(
                  label: 'Profedex',
                  value: collection.captured,
                  total: collection.total,
                  color: collection.completed
                      ? AppColors.success
                      : AppColors.accent,
                ),
                if (collection.completed) ...[
                  const SizedBox(height: 12),
                  Text(
                    '¡Has capturado a todos los profesores!',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SuccessActions extends StatelessWidget {
  const _SuccessActions({required this.args});

  final CaptureResultArgs args;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (args.collectionCompleted) ...[
          PixelButton(
            label: '¡Profedex completada!',
            icon: Icons.emoji_events,
            onPressed: () => context.go(AppRoutes.completion),
          ),
          const SizedBox(height: 10),
        ],
        PixelButton(
          label: 'Ver Profedex',
          icon: Icons.grid_view,
          variant: args.collectionCompleted
              ? PixelButtonVariant.secondary
              : PixelButtonVariant.primary,
          onPressed: () => context.go(AppRoutes.collection),
        ),
        const SizedBox(height: 10),
        PixelButton(
          label: 'Volver al mapa',
          icon: Icons.map_outlined,
          variant: PixelButtonVariant.secondary,
          onPressed: () => context.go(AppRoutes.map),
        ),
      ],
    );
  }
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.args});

  final CaptureResultArgs args;

  @override
  Widget build(BuildContext context) {
    final professor = args.professor;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        RetroDialogue(
          text: '¡${professor.displayName} se escapó! Vuelve a leer la tarjeta.',
          minHeight: 42,
        ),
        const SizedBox(height: 20),
        PixelCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0.28,
                    child: ProfessorSprite(
                      professorId: professor.id,
                      spriteUrl: professor.spriteUrl,
                      size: 140,
                      silhouette: true,
                    ),
                  ),
                  Opacity(
                        opacity: 0.75,
                        child: ProfessorSprite(
                          professorId: professor.id,
                          spriteUrl: professor.spriteUrl,
                          size: 140,
                          semanticLabel: professor.displayName,
                        ),
                      )
                      .animate()
                      .slideX(
                        begin: 0,
                        end: 0.6,
                        duration: 700.ms,
                        curve: Curves.easeIn,
                      )
                      .fadeOut(duration: 700.ms),
                ],
              ),
              const SizedBox(height: 14),
              Text(professor.displayName, style: textTheme.titleLarge),
              const SizedBox(height: 8),
              RarityBadge(professor.rarity),
              if (args.quality != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Lanzamiento: ${args.quality!.label}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Para intentarlo de nuevo, encuentra al profesor y lee su tarjeta NFC otra vez.',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _FailureActions extends StatelessWidget {
  const _FailureActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelButton(
          label: 'Volver al mapa',
          icon: Icons.map_outlined,
          onPressed: () => context.go(AppRoutes.map),
        ),
        const SizedBox(height: 10),
        PixelButton(
          label: 'Leer otra tarjeta',
          icon: Icons.nfc,
          variant: PixelButtonVariant.secondary,
          onPressed: () => context.go(AppRoutes.scan),
        ),
      ],
    );
  }
}
