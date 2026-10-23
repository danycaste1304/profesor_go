import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/audio/game_music_controller.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/models/collection_progress.dart';
import '../../../core/widgets/widgets.dart';
import '../../avatar/avatar_style.dart';
import 'completion_banner_state.dart';
import 'map_controller.dart';
import 'widgets/campus_map.dart';

/// Home hub: collection progress, connectivity, the campus map with the
/// player's avatar and the main actions (capture / collection / profile).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  static const String offlineCaptureMessage =
      'No puedes iniciar una captura sin conexión.';

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  /// Below this height the hub scrolls instead of squeezing the map.
  static const double _minContentHeight = 560;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the settings screen: re-check the permission.
    if (state == AppLifecycleState.resumed &&
        !ref.read(mapControllerProvider).isAvailable) {
      ref.read(mapControllerProvider.notifier).retry();
    }
  }

  Future<void> _refresh() async {
    invalidateCollection(ref);
    if (!ref.read(mapControllerProvider).isAvailable) {
      ref.read(mapControllerProvider.notifier).retry();
    }
    try {
      await ref.read(collectionProgressProvider.future);
    } catch (_) {
      // The error is rendered by the progress chip.
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapControllerProvider);
    final online = ref.watch(connectivityProvider).value ?? true;
    final progressAsync = ref.watch(collectionProgressProvider);
    final progress =
        progressAsync.value ??
        ref.watch(professorRepositoryProvider).cache.progress;
    final bannerSeen = ref.watch(completionBannerSeenProvider);
    final showBanner = (progress?.completed ?? false) && !bannerSeen;

    return AppScaffold(
      showAppBar: false,
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.hasBoundedHeight
                ? math.max(constraints.maxHeight, _minContentHeight)
                : _minContentHeight;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _MapPanel(state: mapState)),
                      Positioned(
                        left: 8,
                        right: 8,
                        top: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PixelCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: _Header(online: online),
                            ),
                            const SizedBox(height: 8),
                            _ProgressChip(
                              progress: progress,
                              progressAsync: progressAsync,
                            ),
                            if (showBanner) ...[
                              const SizedBox(height: 8),
                              _CompletionBanner(
                                onView: () {
                                  ref
                                      .read(
                                        completionBannerSeenProvider.notifier,
                                      )
                                      .markSeen();
                                  context.push(AppRoutes.completion);
                                },
                                onDismiss: () => ref
                                    .read(completionBannerSeenProvider.notifier)
                                    .markSeen(),
                              ),
                            ],
                            if (mapState.message != null) ...[
                              const SizedBox(height: 8),
                              _LocationNotice(
                                message: mapState.message!,
                                showSettings: mapState.canOpenSettings,
                                onOpenSettings: () => _openSettings(context),
                                onRetry: ref
                                    .read(mapControllerProvider.notifier)
                                    .retry,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: PixelCard(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PixelButton(
                                label: 'Capturar',
                                icon: Icons.nfc,
                                onPressed: online
                                    ? () => context.push(AppRoutes.scan)
                                    : null,
                              ),
                              if (!online)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    MapScreen.offlineCaptureMessage,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppColors.danger),
                                  ),
                                ),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  Expanded(
                                    child: PixelButton(
                                      label: 'Profedex',
                                      icon: Icons.menu_book,
                                      variant: PixelButtonVariant.secondary,
                                      onPressed: () =>
                                          context.push(AppRoutes.collection),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: PixelButton(
                                      label: 'Perfil',
                                      icon: Icons.person,
                                      variant: PixelButtonVariant.secondary,
                                      onPressed: () =>
                                          context.push(AppRoutes.profile),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref
        .read(mapControllerProvider.notifier)
        .openSettings();
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron abrir los ajustes. Ábrelos desde el móvil.',
          ),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Header: title + connectivity indicator
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.success : AppColors.danger;
    final label = online ? 'En línea' : 'Sin conexión';
    return Row(
      children: [
        Expanded(
          child: Text(
            'Campus USFQ',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: AppColors.text),
          ),
        ),
        Semantics(
          label: 'Conexión: $label',
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  online ? Icons.wifi : Icons.wifi_off,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Collection progress chip
// ---------------------------------------------------------------------------

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({required this.progress, required this.progressAsync});

  /// Fresh or cached progress; `null` when nothing is known yet.
  final CollectionProgress? progress;
  final AsyncValue<CollectionProgress> progressAsync;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: AppColors.textMuted);

    Widget child;
    if (p != null) {
      child = ProgressBar(
        value: p.captured,
        total: p.total,
        label: 'Profes Capturados',
        height: 20,
        color: p.completed ? AppColors.success : AppColors.accent,
      );
    } else if (progressAsync.hasError) {
      child = Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppException.from(progressAsync.error!).message,
              style: muted,
            ),
          ),
        ],
      );
    } else {
      child = Text('Cargando tu Profedex…', style: muted);
    }

    return PixelCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Completion banner
// ---------------------------------------------------------------------------

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.onView, required this.onDismiss});

  final VoidCallback onView;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return PixelCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      borderColor: AppColors.accent,
      color: AppColors.surfaceAlt,
      semanticLabel: 'Profedex completada',
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: AppColors.accentText, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '¡Profedex completada!',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppColors.accentText),
            ),
          ),
          PixelButton(
            label: 'Ver',
            onPressed: onView,
            expand: false,
            minHeight: 48,
          ),
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location problem notice
// ---------------------------------------------------------------------------

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({
    required this.message,
    required this.showSettings,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final String message;
  final bool showSettings;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PixelCard(
      padding: const EdgeInsets.all(12),
      borderColor: AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_off, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (showSettings) ...[
                Expanded(
                  child: PixelButton(
                    label: 'Abrir ajustes',
                    icon: Icons.settings,
                    variant: PixelButtonVariant.secondary,
                    onPressed: onOpenSettings,
                    minHeight: 48,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: PixelButton(
                  label: 'Reintentar',
                  icon: Icons.refresh,
                  variant: PixelButtonVariant.secondary,
                  onPressed: onRetry,
                  minHeight: 48,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map panel: the map plus its overlays (status chip, demo toggle)
// ---------------------------------------------------------------------------

class _MapPanel extends ConsumerWidget {
  const _MapPanel({required this.state});

  final MapState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final music = ref.watch(gameMusicControllerProvider);
    final String? statusText;
    if (state.isChecking) {
      statusText = 'Buscando tu ubicación…';
    } else if (state.isAvailable && state.current == null) {
      statusText = 'Esperando señal GPS…';
    } else if (state.isAvailable && !state.isInsideCampus) {
      statusText = 'Estás fuera del campus';
    } else {
      statusText = null;
    }

    return PixelCard(
      padding: EdgeInsets.zero,
      borderColor: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CampusMap(
              avatarOffset: state.mapOffset,
              config: state.config,
              avatarStyle: ref.watch(avatarStyleProvider),
            ),
            if (statusText != null)
              Positioned(
                left: 8,
                top: 150,
                child: _OverlayChip(
                  icon: state.isChecking ? Icons.gps_not_fixed : Icons.gps_off,
                  text: statusText,
                ),
              ),
            if (state.canSimulate)
              Positioned(
                right: 8,
                bottom: 164,
                child: _SimulationToggle(
                  value: state.simulating,
                  onChanged: ref
                      .read(mapControllerProvider.notifier)
                      .setSimulation,
                ),
              ),
            Positioned(
              right: 8,
              bottom: state.canSimulate ? 222 : 164,
              child: PixelIconButton(
                icon: music.enabled ? Icons.music_note : Icons.music_off,
                semanticLabel: 'Música del juego',
                toggled: music.enabled,
                onPressed: music.busy
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(gameMusicControllerProvider.notifier)
                              .toggle();
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo reproducir la música.',
                                ),
                              ),
                            );
                          }
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.85),
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accentAlt),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Demo-only switch that starts / pauses the mock walk along the demo path.
class _SimulationToggle extends StatelessWidget {
  const _SimulationToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Simular movimiento',
      toggled: value,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.85),
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.directions_walk,
              size: 16,
              color: AppColors.accentAlt,
            ),
            const SizedBox(width: 6),
            const Text(
              'Simular movimiento',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}
