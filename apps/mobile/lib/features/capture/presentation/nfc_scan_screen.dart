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
import '../../../core/models/profile.dart';
import '../../../core/nfc/mock_nfc_service.dart';
import '../../../core/nfc/nfc_service.dart';
import '../../../core/widgets/widgets.dart';
import 'nfc_settings_opener.dart';
import 'widgets/battle_wipe.dart';

enum _ScanStatus {
  /// Checking connectivity / NFC availability.
  checking,

  /// NFC session open, waiting for a card.
  scanning,

  /// Demo mode: waiting for the player to choose a mock card.
  choosing,

  /// Card read; `start-encounter` in flight.
  starting,
  unsupported,
  disabled,
  offline,
  found,
  error,
}

/// `/scan` — reads the professor card and starts the encounter.
class NfcScanScreen extends ConsumerStatefulWidget {
  const NfcScanScreen({super.key});

  @override
  ConsumerState<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends ConsumerState<NfcScanScreen> {
  _ScanStatus _status = _ScanStatus.checking;
  String? _errorMessage;
  String? _unregisteredTag;
  List<DemoTag>? _demoTags;
  bool _starting = false;

  /// Incremented on every (re)start so stale scan results are ignored.
  int _session = 0;

  /// Captured in [initState]: `ref` must not be used from [dispose].
  late final NfcService _nfc;
  late final GameMusicController _music;

  /// The tag picker is essential in every demo build: without it a release
  /// demo can only ever scan the first mock card.
  bool get _showDemoPicker => AppConfig.isDemoMode && _demoTags != null;

  @override
  void initState() {
    super.initState();
    _nfc = ref.read(nfcServiceProvider);
    _music = ref.read(gameMusicControllerProvider.notifier);
    unawaited(_loadDemoTags());
    unawaited(_begin());
  }

  @override
  void dispose() {
    _session++;
    unawaited(_nfc.cancel());
    // No-op once the encounter has taken over the battle music.
    _music.leaveScene(this);
    super.dispose();
  }

  Future<void> _loadDemoTags() async {
    if (!AppConfig.isDemoMode) return;
    final nfc = _nfc;
    if (nfc is! MockNfcService) return;
    final tags = await nfc.demoTags();
    if (mounted) setState(() => _demoTags = tags);
  }

  void _set(_ScanStatus status, {String? message, String? unregisteredTag}) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _errorMessage = message;
      _unregisteredTag = unregisteredTag;
    });
  }

  /// Entry point (also for "Reintentar"): connectivity → availability → scan.
  Future<void> _begin() async {
    final session = ++_session;
    await _nfc.cancel();
    _set(_ScanStatus.checking);
    if (!ref.read(isOnlineProvider)) {
      _set(_ScanStatus.offline);
      return;
    }
    if (AppConfig.isDemoMode && _nfc is MockNfcService) {
      _set(_ScanStatus.choosing);
      return;
    }
    NfcAvailability availability;
    try {
      availability = await _nfc.availability();
    } catch (_) {
      availability = NfcAvailability.unsupported;
    }
    if (!mounted || session != _session) return;
    switch (availability) {
      case NfcAvailability.unsupported:
        _set(_ScanStatus.unsupported);
      case NfcAvailability.disabled:
        _set(_ScanStatus.disabled);
      case NfcAvailability.available:
        await _scan(session);
    }
  }

  Future<void> _scan(int session) async {
    _set(_ScanStatus.checking);
    String? tag;
    try {
      tag = await _nfc.scanTag(
        onReady: () {
          if (mounted && session == _session) _set(_ScanStatus.scanning);
        },
      );
    } on AppException catch (e) {
      if (!mounted || session != _session) return;
      switch (e.code) {
        case AppException.nfcUnsupported:
          _set(_ScanStatus.unsupported);
        case AppException.nfcDisabled:
          _set(_ScanStatus.disabled);
        default:
          _set(_ScanStatus.error, message: e.message);
      }
      return;
    } catch (e) {
      if (!mounted || session != _session) return;
      _set(_ScanStatus.error, message: AppException.from(e).message);
      return;
    }
    if (!mounted || session != _session) return;
    if (tag == null) {
      _set(
        _ScanStatus.error,
        message: 'No se detectó ninguna tarjeta. Acerca el teléfono e inténtalo de nuevo.',
      );
      return;
    }
    await _handleTag(tag);
  }

  /// Shared by the real scan and the demo picker.
  Future<void> _handleTag(String tag) async {
    if (_starting) return; // double-submission guard
    _starting = true;
    _session++;
    _set(_ScanStatus.starting);
    HuntCheckin? huntCheckin;
    try {
      // The hunt's attendance record is separate from the once-per-professor
      // Profedex capture. A player who already caught this professor still
      // receives credit for finding them at this event.
      if (!AppConfig.isDemoMode) {
        huntCheckin = await ref.read(huntServiceProvider).checkIn(tag);
      }
      final encounter = await ref
          .read(captureServiceProvider)
          .startEncounter(tag);
      if (!mounted) return;
      if (huntCheckin != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              huntCheckin.alreadyRegistered
                  ? 'Este hallazgo ya estaba registrado para la feria.'
                  : '¡Hallazgo registrado para la feria!',
            ),
          ),
        );
      }
      // The battle music starts with the wipe, as in a wild encounter; the
      // encounter screen keeps it playing without restarting it.
      unawaited(
        _music.enterScene(GameMusicCue.battle, this).catchError((Object _) {}),
      );
      await BattleWipe.play(
        context,
        onCovered: () {
          if (!mounted) return;
          context.go(AppRoutes.encounter(encounter.id), extra: encounter);
        },
      );
    } catch (e) {
      final error = AppException.from(e);
      if (error.code == AppException.alreadyCaptured && huntCheckin != null) {
        _set(
          _ScanStatus.found,
          message: huntCheckin.alreadyRegistered
              ? 'Ya registramos que encontraste al profesor en esta búsqueda.'
              : '¡Encontraste al profesor! Tu hallazgo quedó registrado '
                    'para la actividad, aunque ya estaba en tu Profedex.',
        );
        return;
      }
      String? unregisteredTag;
      if (!AppConfig.isDemoMode && error.code == AppException.tagNotFound) {
        try {
          final profile = await ref.read(profileProvider.future);
          if (profile?.role == UserRole.admin) unregisteredTag = tag;
        } catch (_) {
          // Registration details are only shown after confirming admin role.
        }
      }
      if (!mounted) return;
      _set(
        _ScanStatus.error,
        message: huntCheckin == null
            ? error.message
            : 'Tu hallazgo para la feria quedó registrado. '
                  'El encuentro no pudo abrirse: ${error.message}',
        unregisteredTag: unregisteredTag,
      );
    } finally {
      _starting = false;
    }
  }

  Future<void> _pickDemoTag(DemoTag tag) async {
    final nfc = _nfc;
    if (nfc is MockNfcService) nfc.selectTag(tag.identifier);
    await nfc.cancel();
    await _handleTag(tag.identifier);
  }

  /// Android only: opens the system NFC settings. A missing channel or a
  /// platform error resolves to false and is explained in a snackbar.
  Future<void> _openNfcSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref.read(nfcSettingsOpenerProvider)();
    if (!mounted || opened) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudieron abrir los ajustes de NFC. '
          'Actívalo desde los ajustes del móvil.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isOnlineProvider, (previous, online) {
      if (online && _status == _ScanStatus.offline) {
        unawaited(_begin());
      } else if (!online &&
          (_status == _ScanStatus.scanning ||
              _status == _ScanStatus.checking)) {
        _session++;
        unawaited(_nfc.cancel());
        _set(_ScanStatus.offline);
      }
    });
    return AppScaffold(
      title: 'Leer tarjeta',
      homeFallback: true,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatus(context),
                if (_showDemoPicker) ...[
                  const SizedBox(height: 28),
                  _DemoTagPicker(
                    tags: _demoTags!,
                    enabled: _status != _ScanStatus.starting,
                    onPick: _pickDemoTag,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(BuildContext context) {
    switch (_status) {
      case _ScanStatus.checking:
        return const LoadingView(message: 'Comprobando el NFC…');
      case _ScanStatus.starting:
        return const LoadingView(message: 'Buscando al profesor…');
      case _ScanStatus.scanning:
        return const _ScanningView();
      case _ScanStatus.choosing:
        return const _MessageView(
          icon: PixelIcons.creditCard,
          iconColor: AppColors.accentAlt,
          title: 'Elige una tarjeta demo',
          message:
              'Selecciona un profesor en la lista para comenzar el encuentro.',
        );
      case _ScanStatus.unsupported:
        return _MessageView(
          icon: PixelIcons.nfc,
          title: 'Este dispositivo no tiene NFC',
          message: _showDemoPicker
              ? 'Elige una tarjeta de demostración para probar el juego.'
              : 'Necesitas un móvil con NFC para leer las tarjetas de los profesores.',
        );
      case _ScanStatus.disabled:
        return _MessageView(
          icon: PixelIcons.settings,
          title: 'Activa el NFC en los ajustes',
          message: AppException.messages[AppException.nfcDisabled]!,
          onRetry: _begin,
          // Hidden where there is no NFC settings screen to open (iOS, web).
          onOpenSettings: ref.watch(canOpenNfcSettingsProvider)
              ? _openNfcSettings
              : null,
        );
      case _ScanStatus.offline:
        return _MessageView(
          icon: PixelIcons.wifiOff,
          title: 'Sin conexión',
          message: AppException.messages[AppException.noInternet]!,
          onRetry: _begin,
        );
      case _ScanStatus.found:
        return _MessageView(
          icon: PixelIcons.badge,
          iconColor: AppColors.success,
          title: '¡Profesor encontrado!',
          message: _errorMessage ?? 'Tu hallazgo quedó registrado.',
          onDone: () => context.go(AppRoutes.map),
        );
      case _ScanStatus.error:
        return _MessageView(
          icon: PixelIcons.error,
          title: 'No se pudo empezar',
          message:
              _errorMessage ?? AppException.messages[AppException.unknown]!,
          unregisteredTag: _unregisteredTag,
          onRetry: _begin,
        );
    }
  }
}

/// Pulsing ball + NFC waves while the session is open. One repeating
/// [AnimationController] drives everything (no timers, test friendly).
class _ScanningView extends StatefulWidget {
  const _ScanningView();

  @override
  State<_ScanningView> createState() => _ScanningViewState();
}

class _ScanningViewState extends State<_ScanningView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 240,
          height: 240,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final pulse = 1 + 0.06 * math.sin(t * 2 * math.pi);
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    _wave(Curves.easeOut.transform((t + i / 3) % 1)),
                  Transform.scale(
                    scale: pulse,
                    child: const CaptureBall(size: 120),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity:
                0.55 +
                0.45 * (0.5 + 0.5 * math.sin(_controller.value * 2 * math.pi)),
            child: child,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PixelIcon(PixelIcons.nfc, color: AppColors.accentAlt),
              const SizedBox(width: 8),
              Text(
                'BUSCANDO TARJETA',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.accentAlt,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Acerca tu teléfono a la tarjeta del profesor',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
        ),
      ],
    );
  }

  /// Expanding, fading ring at progress [p] (0..1).
  static Widget _wave(double p) => Opacity(
    opacity: (1 - p).clamp(0.0, 1.0),
    child: Container(
      width: 120 + 120 * p,
      height: 120 + 120 * p,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accentAlt, width: 3),
      ),
    ),
  );
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor = AppColors.danger,
    this.onRetry,
    this.onOpenSettings,
    this.onDone,
    this.unregisteredTag,
  });

  final PixelIconData icon;
  final String title;
  final String message;
  final Color iconColor;
  final Future<void> Function()? onRetry;

  /// When set, the primary action opens the system settings.
  final Future<void> Function()? onOpenSettings;
  final VoidCallback? onDone;
  final String? unregisteredTag;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: PixelCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelIcon(icon, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
            ),
            if (unregisteredTag != null) ...[
              const SizedBox(height: 16),
              Text(
                'Identificador para registrar en el panel admin:',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              SelectableText(
                unregisteredTag!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (onOpenSettings != null) ...[
              const SizedBox(height: 24),
              PixelButton(
                label: 'Abrir ajustes de NFC',
                icon: PixelIcons.settings,
                onPressed: () => unawaited(onOpenSettings!()),
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: onOpenSettings == null ? 24 : 12),
              PixelButton(
                label: 'Reintentar',
                icon: PixelIcons.refresh,
                variant: onOpenSettings == null
                    ? PixelButtonVariant.tertiary
                    : PixelButtonVariant.secondary,
                onPressed: () => unawaited(onRetry!()),
              ),
            ],
            if (onDone != null) ...[
              const SizedBox(height: 24),
              PixelButton(
                label: 'Volver al mapa',
                icon: PixelIcons.map,
                onPressed: onDone,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Demo-only list of mock cards (DEMO-TAG-01…10).
class _DemoTagPicker extends StatelessWidget {
  const _DemoTagPicker({
    required this.tags,
    required this.enabled,
    required this.onPick,
  });

  final List<DemoTag> tags;
  final bool enabled;
  final Future<void> Function(DemoTag tag) onPick;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'TARJETAS DEMO',
              style: textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final tag in tags)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PixelCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              semanticLabel: 'Tarjeta demo ${tag.label}',
              onTap: enabled ? () => unawaited(onPick(tag)) : null,
              child: Row(
                children: [
                  const PixelIcon(
                    PixelIcons.creditCard,
                    color: AppColors.accentAlt,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(tag.label, style: textTheme.titleMedium),
                  ),
                  Text(
                    tag.identifier,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Text(
          'Solo visible en modo demo',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}
