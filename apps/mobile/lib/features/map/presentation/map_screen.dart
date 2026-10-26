import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/audio/game_music_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/hunt/hunt_service.dart';
import '../../../core/models/collection_progress.dart';
import '../../../core/widgets/widgets.dart';
import '../../avatar/avatar_style.dart';
import 'completion_banner_state.dart';
import 'map_controller.dart';
import 'widgets/campus_live_map.dart';
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
  Timer? _huntRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!AppConfig.isDemoMode) {
      _huntRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) ref.invalidate(activeHuntsProvider);
      });
    }
  }

  @override
  void dispose() {
    _huntRefreshTimer?.cancel();
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
    if (!AppConfig.isDemoMode) ref.invalidate(activeHuntsProvider);
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
    final hunts = AppConfig.isDemoMode
        ? const <HuntSession>[]
        : (ref.watch(activeHuntsProvider).value ?? const <HuntSession>[]);
    final canPublish =
        !AppConfig.isDemoMode && ref.watch(huntPublisherProvider).value != null;
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
                      Positioned.fill(
                        child: _MapPanel(state: mapState, hunts: hunts),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        top: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ProgressChip(
                              progress: progress,
                              progressAsync: progressAsync,
                            ),
                            const SizedBox(height: 8),
                            _StatusPills(online: online),
                            if (hunts.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              PixelPill(
                                label: 'Busca a ${hunts.first.professorName}',
                                icon: PixelIcons.pin,
                                color: AppColors.accent,
                                tinted: true,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ubicación aproximada · actualizada hace '
                                '${DateTime.now().toUtc().difference(hunts.first.locatedAt!).inSeconds.clamp(0, 29)} s '
                                '· precisión ±${(hunts.first.accuracyMeters ?? 0).round()} m',
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
                                icon: PixelIcons.nfc,
                                variant: PixelButtonVariant.primary,
                                onPressed: online
                                    ? () => context.push(AppRoutes.scan)
                                    : null,
                              ),
                              if (canPublish) ...[
                                const SizedBox(height: 9),
                                PixelButton(
                                  label: 'Compartir ubicación',
                                  icon: PixelIcons.pin,
                                  variant: PixelButtonVariant.secondary,
                                  onPressed: () =>
                                      context.push(AppRoutes.huntHost),
                                ),
                              ],
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
                                      icon: PixelIcons.book,
                                      // Tertiary is PixelButton's default
                                      // variant (the linter rejects stating it).
                                      onPressed: () =>
                                          context.push(AppRoutes.collection),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: PixelButton(
                                      label: 'Perfil',
                                      icon: PixelIcons.person,
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
// Status pills: location + connectivity indicator
// ---------------------------------------------------------------------------

class _StatusPills extends StatelessWidget {
  const _StatusPills({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.success : AppColors.danger;
    final label = online ? 'En línea' : 'Sin conexión';
    // Wrap, not Row: both pills together can exceed a 320 px screen.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        const PixelPill(
          label: 'Campus USFQ',
          icon: PixelIcons.pin,
          color: AppColors.danger,
          tinted: true,
        ),
        Semantics(
          label: 'Conexión: $label',
          liveRegion: true,
          child: PixelPill(
            label: label,
            icon: online ? PixelIcons.wifi : PixelIcons.wifiOff,
            color: color,
            tinted: true,
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
        label: 'PROFES CAPTURADOS',
        height: 20,
        showCount: true,
        showPercent: false,
        color: p.completed ? AppColors.success : AppColors.accent,
      );
    } else if (progressAsync.hasError) {
      child = Row(
        children: [
          const PixelIcon(PixelIcons.error, color: AppColors.danger),
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
          const PixelIcon(PixelIcons.trophy, color: AppColors.accentText),
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
            icon: const PixelIcon(PixelIcons.close),
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
              const PixelIcon(PixelIcons.locationOff, color: AppColors.danger),
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
                    icon: PixelIcons.settings,
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
                  icon: PixelIcons.refresh,
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
  const _MapPanel({required this.state, required this.hunts});

  final MapState state;
  final List<HuntSession> hunts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final music = ref.watch(gameMusicControllerProvider);
    final String? statusText;
    if (state.isChecking) {
      statusText = 'Buscando tu ubicación…';
    } else if (state.isAvailable && state.current == null) {
      statusText = 'Esperando señal GPS…';
    } else if (AppConfig.isDemoMode &&
        state.isAvailable &&
        !state.isInsideCampus) {
      statusText = 'Ubicación fuera del mapa actual';
    } else if (state.isAvailable && !AppConfig.isDemoMode) {
      statusText = 'GPS aproximado';
    } else {
      statusText = null;
    }

    return PixelCard(
      padding: EdgeInsets.zero,
      borderColor: AppColors.onAccent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppConfig.isDemoMode
                ? CampusMap(
                    avatarOffset: state.mapOffset,
                    config: state.config,
                    avatarStyle: ref.watch(avatarStyleProvider),
                  )
                : CampusLiveMap(playerPosition: state.current, hunts: hunts),
            if (statusText != null)
              Positioned(
                left: 8,
                top: 150,
                child: _OverlayChip(
                  icon: state.isChecking
                      ? PixelIcons.gpsNotFixed
                      : PixelIcons.gpsOff,
                  text: statusText,
                ),
              ),
            Positioned(
              right: 8,
              bottom: 164,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Demo-only toggle that starts / pauses the mock walk along
                  // the demo path.
                  if (state.canSimulate) ...[
                    PixelIconButton(
                      icon: PixelIcons.walk,
                      semanticLabel: 'Simular movimiento',
                      toggled: state.simulating,
                      onPressed: () => ref
                          .read(mapControllerProvider.notifier)
                          .setSimulation(!state.simulating),
                    ),
                    const SizedBox(width: 8),
                  ],
                  PixelIconButton(
                    icon: music.enabled
                        ? PixelIcons.musicNote
                        : PixelIcons.musicOff,
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
                ],
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

  final PixelIconData icon;
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
          PixelIcon(icon, color: AppColors.accentAlt),
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
