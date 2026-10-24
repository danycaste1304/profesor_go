import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/audio/encounter_sound_effects.dart';
import '../../../core/audio/scene_music.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/models/encounter.dart';
import '../../../core/models/featured_professors.dart';
import '../../../core/models/throw_quality.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/capture_result_args.dart';
import '../domain/throw_quality_calculator.dart';
import 'encounter_backdrop.dart';
import 'encounter_controller.dart';

/// `/encounter/:encounterId` — the throw mini-game.
///
/// The [Encounter] arrives as the route `extra` (from `/scan`); when it is
/// missing (deep link, hot restart) it is recovered from the
/// `CaptureService` cache. Without either, a friendly error + way back.
class EncounterScreen extends ConsumerWidget {
  const EncounterScreen({super.key, required this.encounterId});

  /// From the `/encounter/:encounterId` path parameter.
  final String encounterId;

  Encounter? _resolveEncounter(BuildContext context, WidgetRef ref) {
    final cached = ref
        .read(captureServiceProvider)
        .cachedEncounter(encounterId);
    if (cached != null) return cached;
    Object? extra;
    try {
      extra = GoRouterState.of(context).extra;
    } catch (_) {
      // Not under a GoRouter route (tests / previews): no extra available.
    }
    if (extra is Encounter) return extra;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final encounter = _resolveEncounter(context, ref);
    if (encounter == null) {
      return _EncounterErrorScreen(
        message: AppException.messages[AppException.encounterNotFound]!,
      );
    }
    if (encounter.status != EncounterStatus.active) {
      return _EncounterErrorScreen(
        message: AppException.messages[AppException.encounterNotActive]!,
      );
    }
    return _EncounterView(key: ValueKey(encounter.id), encounter: encounter);
  }
}

class _EncounterErrorScreen extends StatelessWidget {
  const _EncounterErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Encuentro',
      body: ErrorView(
        message: message,
        icon: Icons.search_off,
        retryLabel: 'Leer otra tarjeta',
        onRetry: () => context.go(AppRoutes.scan),
      ),
      bottomBar: PixelButton(
        label: 'Volver al mapa',
        icon: Icons.map_outlined,
        variant: PixelButtonVariant.secondary,
        onPressed: () => context.go(AppRoutes.map),
      ),
    );
  }
}

/// Visual steps of the throw sequence.
enum _Step { idle, fly, absorb, drop, shake, burst, popOut, missFly, dodge }

class _EncounterView extends ConsumerStatefulWidget {
  const _EncounterView({super.key, required this.encounter});

  final Encounter encounter;

  @override
  ConsumerState<_EncounterView> createState() => _EncounterViewState();
}

class _EncounterViewState extends ConsumerState<_EncounterView>
    with TickerProviderStateMixin {
  static const double _ballSize = 96;
  static const double _spriteSize = 160;

  /// Keep the professor in the upper middle of taller phones, rather than
  /// pinning the portrait against the top edge of the outdoor scene.
  double get _spriteTop => math.min(80, math.max(16, _arena.height * 0.1));

  /// Gestures shorter than this are taps, not throws: the ball just snaps back.
  static const double _tapDeadZone = 8;

  static const Duration _flyDuration = Duration(milliseconds: 500);
  static const Duration _absorbDuration = Duration(milliseconds: 280);
  static const Duration _dropDuration = Duration(milliseconds: 500);
  static const Duration _shakeDuration = Duration(milliseconds: 360);
  static const Duration _burstDuration = Duration(milliseconds: 1660);
  static const Duration _popOutDuration = Duration(milliseconds: 1000);
  static const Duration _missDuration = Duration(milliseconds: 1000);
  static const Duration _dodgeDuration = Duration(milliseconds: 1600);

  final GlobalKey _arenaKey = GlobalKey();
  final GlobalKey _spriteKey = GlobalKey();

  late final AnimationController _anim;
  late final AnimationController _bob;
  late final EncounterSoundEffects _soundEffects;

  _Step _step = _Step.idle;
  Size _arena = Size.zero;
  Offset? _ballPos; // ball center in arena coordinates (null → rest)
  Offset _flyFrom = Offset.zero;
  Offset _flyTo = Offset.zero;
  Offset _missDirection = const Offset(0, -1);
  Offset? _dragStart;
  Offset? _dragLast;
  Offset? _contactStart;
  DateTime? _dragStartTime;
  bool _dragging = false;
  bool _sequenceStarted = false;
  bool _errorShown = false;
  bool _navigated = false;
  bool _introLineVisible = false;
  Timer? _introLineTimer;
  String? _statusText;
  Color _statusColor = AppColors.accent;

  Encounter get _encounter => widget.encounter;

  @override
  void initState() {
    super.initState();
    _soundEffects = EncounterSoundEffects();
    if (_encounter.professor.id == danielRiofrioId ||
        _encounter.professor.id == erickNaunayId ||
        _encounter.professor.id == noelPerezId ||
        _encounter.professor.id == pavelAlbaId ||
        _encounter.professor.id == ricardoFloresId ||
        _encounter.professor.id == joseDavidVegaId ||
        _encounter.professor.id == felipeGrijalvaId ||
        _encounter.professor.id == henryCarvajalId ||
        _encounter.professor.id == diegoMoralesId ||
        _encounter.professor.id == robertoAndradeId) {
      _introLineVisible = true;
      _introLineTimer = Timer(const Duration(milliseconds: 2800), () {
        if (mounted) setState(() => _introLineVisible = false);
      });
    }
    _anim = AnimationController(vsync: this);
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(encounterControllerProvider(_encounter));
      if (state.phase == EncounterPhase.error) _showErrorDialog(state.error);
    });
  }

  @override
  void dispose() {
    _introLineTimer?.cancel();
    unawaited(_soundEffects.dispose());
    _anim.dispose();
    _bob.dispose();
    super.dispose();
  }

  // ---- Geometry -----------------------------------------------------------

  Offset get _restPosition =>
      Offset(_arena.width / 2, _arena.height - _ballSize / 2 - 28);

  Offset get _spriteRestCenter =>
      Offset(_arena.width / 2, _spriteTop + _spriteSize / 2);

  RenderBox? get _arenaBox =>
      _arenaKey.currentContext?.findRenderObject() as RenderBox?;

  /// Sprite center in arena coordinates (from its GlobalKey), or the layout
  /// position when it has not been laid out yet.
  Offset _spriteCenter() {
    final sprite = _spriteKey.currentContext?.findRenderObject() as RenderBox?;
    final arena = _arenaBox;
    if (sprite == null || arena == null || !sprite.hasSize) {
      return _spriteRestCenter;
    }
    return sprite.localToGlobal(
      sprite.size.center(Offset.zero),
      ancestor: arena,
    );
  }

  Offset _toArena(Offset global) {
    final arena = _arenaBox;
    return arena == null ? global : arena.globalToLocal(global);
  }

  // ---- Gestures -----------------------------------------------------------

  bool get _canDrag =>
      ref.read(encounterControllerProvider(_encounter)).canThrow &&
      _step == _Step.idle &&
      !_sequenceStarted;

  void _onPanDown(DragDownDetails d) {
    if (!_canDrag) return;
    final point = _toArena(d.globalPosition);
    final nearBottom = point.dy >= _restPosition.dy - _ballSize * 1.5;
    final nearBall =
        (point.dx - _restPosition.dx).abs() <=
        math.max(_ballSize * 1.7, _arena.width * 0.35);
    _contactStart = nearBottom && nearBall ? point : null;
  }

  void _onPanStart(DragStartDetails d) {
    if (!_canDrag || _contactStart == null) return;
    _dragStart = _contactStart;
    _dragLast = _dragStart;
    _dragStartTime = DateTime.now();
    setState(() {
      _dragging = true;
      _introLineVisible = false;
      _ballPos = _restPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    _dragLast = _toArena(d.globalPosition);
    final delta = _dragLast! - _dragStart!;
    // The hand pulls the ball a little, then release launches it across the
    // arena. It no longer follows the finger all the way to the professor.
    final pull = Offset(
      delta.dx.clamp(-60.0, 60.0) * 0.55,
      delta.dy.clamp(-120.0, 30.0) * 0.45,
    );
    setState(() => _ballPos = _restPosition + pull);
  }

  void _onPanCancel() {
    if (!_dragging) return;
    _snapBack();
  }

  void _snapBack() {
    setState(() {
      _dragging = false;
      _ballPos = null;
      _dragStart = null;
      _dragLast = null;
      _contactStart = null;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_dragging) return;
    final start = _dragStart ?? _restPosition;
    final end = _dragLast ?? start;
    final duration = DateTime.now().difference(
      _dragStartTime ?? DateTime.now(),
    );
    if ((end - start).distance < _tapDeadZone) {
      _snapBack();
      _hint('Desliza la bola hacia arriba, hacia el profesor');
      return;
    }
    final target = _spriteCenter();
    final evaluation = evaluateFlickThrow(
      start: start,
      end: end,
      targetCenter: target,
      duration: duration,
      screenSize: MediaQuery.sizeOf(context),
      targetRadius: _spriteSize * 0.17,
    );
    final launch = _ballPos ?? _restPosition;
    _dragging = false;
    _dragStart = null;
    _dragLast = null;
    _contactStart = null;
    unawaited(
      _runThrow(evaluation, launchPoint: launch, target: evaluation.impact),
    );
  }

  void _hint(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }

  // ---- Throw sequence -----------------------------------------------------

  Future<void> _runThrow(
    FlickThrowEvaluation evaluation, {
    required Offset launchPoint,
    required Offset target,
  }) async {
    if (_sequenceStarted) return;
    final controller = ref.read(
      encounterControllerProvider(_encounter).notifier,
    );
    final quality = evaluation.quality;
    // Backend call starts here, in parallel with the animation.
    if (!controller.throwBall(quality)) {
      _snapBack();
      return;
    }
    _sequenceStarted = true;
    _soundEffects.play(EncounterSound.throwBall);
    if (kDebugMode) {
      debugPrint('throw: ${evaluation.metrics} → ${quality.wireValue}');
    }

    // 1. Animation. Any failure here must never block the backend result.
    try {
      if (quality == ThrowQuality.miss) {
        await _animateMiss(evaluation.metrics, from: launchPoint);
      } else {
        await _animateHit(
          quality,
          controller: controller,
          from: launchPoint,
          target: target,
        );
      }
    } catch (e, st) {
      debugPrint('throw animation failed: $e\n$st');
    }

    // 2. Backend result (already in flight since throwBall).
    final state = await controller.completeThrow();
    if (!mounted) return;

    // 3. Outcome animation, then navigate.
    try {
      switch (state.phase) {
        case EncounterPhase.success:
          await _animateBurst();
        case EncounterPhase.failed:
          await _animateEscape(absorbed: quality != ThrowQuality.miss);
        case EncounterPhase.error:
        case EncounterPhase.idle:
        case EncounterPhase.throwing:
        case EncounterPhase.shaking:
          break;
      }
    } catch (e, st) {
      debugPrint('outcome animation failed: $e\n$st');
    }
    if (!mounted) return;
    if (state.phase == EncounterPhase.success ||
        state.phase == EncounterPhase.failed) {
      _goToResult(state);
    }
    // EncounterPhase.error is handled by the listener (dialog → map).
  }

  Future<void> _animateHit(
    ThrowQuality quality, {
    required EncounterController controller,
    required Offset from,
    required Offset target,
  }) async {
    _flyFrom = from;
    _flyTo = target;
    _setStatus(
      _qualityLabel(quality),
      AppTheme.rarityColor(_encounter.professor.rarity),
    );
    await _play(_Step.fly, _flyDuration, curve: Curves.easeOut);
    _soundEffects.play(EncounterSound.impact);
    await _play(_Step.absorb, _absorbDuration, curve: Curves.easeIn);
    _flyFrom = target;
    _flyTo = target + const Offset(0, 70);
    await _play(_Step.drop, _dropDuration, curve: Curves.bounceOut);
    // `controller` was captured before the first await: never touch `ref`
    // here, the widget may already be unmounted (error dialog → map).
    controller.startShaking();
    _setStatus('…', AppColors.textMuted);
    final shakes = controller.current.shakeCount;
    for (var i = 0; i < shakes; i++) {
      _soundEffects.play(EncounterSound.shake);
      await _play(_Step.shake, _shakeDuration);
    }
  }

  Future<void> _animateMiss(
    ThrowMetrics metrics, {
    required Offset from,
  }) async {
    _flyFrom = from;
    final delta = metrics.delta;
    _missDirection = delta.distance < 1
        ? const Offset(0, -1)
        : delta / delta.distance;
    _setStatus('¡Fallaste!', AppColors.danger);
    await _play(_Step.missFly, _missDuration, curve: Curves.easeOut);
  }

  Future<void> _animateBurst() async {
    _soundEffects.play(EncounterSound.success);
    _setStatus('¡Capturado!', AppColors.success);
    await _play(_Step.burst, _burstDuration, curve: Curves.easeOut);
  }

  Future<void> _animateEscape({required bool absorbed}) async {
    _soundEffects.play(EncounterSound.escape);
    _setStatus('¡Se escapó!', AppColors.danger);
    if (absorbed) {
      await _play(_Step.popOut, _popOutDuration, curve: Curves.elasticOut);
    } else {
      await _play(_Step.dodge, _dodgeDuration, curve: Curves.easeInOut);
    }
  }

  /// Runs [_anim] for one step; resolves when done (or when disposed).
  Future<void> _play(
    _Step step,
    Duration duration, {
    Curve curve = Curves.linear,
  }) async {
    if (!mounted) return;
    setState(() => _step = step);
    _anim
      ..duration = duration
      ..value = 0;
    _curve = curve;
    try {
      await _anim.forward().orCancel;
    } on TickerCanceled {
      // Widget disposed mid-animation: the caller checks `mounted`.
    }
  }

  Curve _curve = Curves.linear;

  double get _t => _curve.transform(_anim.value.clamp(0.0, 1.0));

  void _setStatus(String? text, Color color) {
    if (!mounted) return;
    setState(() {
      _statusText = text;
      _statusColor = color;
    });
  }

  static String _qualityLabel(ThrowQuality q) => switch (q) {
    ThrowQuality.excellent => '¡Excelente!',
    ThrowQuality.great => '¡Genial!',
    ThrowQuality.good => '¡Bien!',
    ThrowQuality.miss => '¡Fallaste!',
  };

  // ---- Navigation ---------------------------------------------------------

  void _goToResult(EncounterState state) {
    if (_navigated) return;
    _navigated = true;
    final result = state.result;
    context.go(
      AppRoutes.result,
      extra: CaptureResultArgs(
        professor: _encounter.professor,
        success: result?.success ?? false,
        collection: result?.collection,
        quality: state.quality,
      ),
    );
  }

  Future<void> _showErrorDialog(AppException? error) async {
    if (_errorShown || !mounted) return;
    _errorShown = true;
    final code = error?.code ?? AppException.unknown;
    final title = switch (code) {
      AppException.encounterExpired => 'El encuentro expiró',
      AppException.encounterNotActive => 'El encuentro terminó',
      AppException.noInternet => 'Sin conexión',
      _ => 'Ups…',
    };
    final message =
        error?.message ?? AppException.messages[AppException.unknown]!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          PixelButton(
            label: 'Volver al mapa',
            icon: Icons.map_outlined,
            expand: false,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (mounted) context.go(AppRoutes.map);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Abandonar el encuentro?'),
        content: const Text(
          'Si sales ahora tendrás que volver a leer la tarjeta NFC del profesor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('SEGUIR JUGANDO'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('SALIR'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) context.go(AppRoutes.map);
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final provider = encounterControllerProvider(_encounter);
    ref.listen<EncounterState>(provider, (previous, next) {
      if (next.phase == EncounterPhase.error &&
          previous?.phase != EncounterPhase.error) {
        unawaited(_showErrorDialog(next.error));
      }
    });
    final state = ref.watch(provider);
    final professor = _encounter.professor;
    final textTheme = Theme.of(context).textTheme;
    final urgent = state.remaining <= const Duration(seconds: 30);

    final page = AppScaffold(
      title: 'Encuentro',
      padding: EdgeInsets.zero,
      leading: IconButton(
        tooltip: 'Salir',
        icon: const Icon(Icons.close),
        onPressed: state.phase == EncounterPhase.idle ? _confirmLeave : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: PixelCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        // Row's default cross-axis alignment keeps the pill
                        // vertically centered on the name.
                        child: Row(
                          children: [
                            // The name ellipsizes first when the countdown
                            // leaves little room.
                            Flexible(
                              child: Text(
                                professor.displayName,
                                style: textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 20),
                            RarityBadge(professor.rarity, compact: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Semantics(
                        label: 'Tiempo restante ${state.countdownLabel}',
                        liveRegion: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              color: urgent
                                  ? AppColors.danger
                                  : AppColors.accentAlt,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              state.countdownLabel,
                              style: textTheme.headlineMedium?.copyWith(
                                color: urgent
                                    ? AppColors.danger
                                    : AppColors.accentAlt,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _EncounterTimeBar(
                    fraction:
                        state.remaining.inMilliseconds /
                        const Duration(minutes: 3).inMilliseconds,
                    urgent: urgent,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _arena = Size(constraints.maxWidth, constraints.maxHeight);
                return AnimatedBuilder(
                  animation: Listenable.merge([_anim, _bob]),
                  builder: (context, _) => _buildArena(state),
                );
              },
            ),
          ),
        ],
      ),
    );
    return SceneMusic(cue: SceneMusicCue.battle, child: page);
  }

  Widget _buildArena(EncounterState state) {
    final professor = _encounter.professor;
    final ball = _ballVisual();
    final sprite = _spriteVisual();
    final textTheme = Theme.of(context).textTheme;
    final showInstructions = state.phase == EncounterPhase.idle && !_dragging;
    FlickThrowEvaluation? aim;
    if (_dragging &&
        _dragStart != null &&
        _dragLast != null &&
        _dragLast!.dy < _dragStart!.dy - 16) {
      aim = evaluateFlickThrow(
        start: _dragStart!,
        end: _dragLast!,
        targetCenter: _spriteCenter(),
        duration: const Duration(milliseconds: 200),
        screenSize: MediaQuery.sizeOf(context),
        targetRadius: _spriteSize * 0.17,
      );
    }
    final needsMorePull =
        aim != null && -aim.metrics.delta.dy < kMinSwipeDistance;
    final aimColor = needsMorePull
        ? AppColors.textMuted
        : switch (aim?.quality) {
            ThrowQuality.excellent => AppColors.success,
            ThrowQuality.great => AppColors.accentAlt,
            ThrowQuality.good => AppColors.accentText,
            ThrowQuality.miss => AppColors.danger,
            null => AppColors.textMuted,
          };
    final aimLabel = aim == null
        ? null
        : needsMorePull
        ? 'DESLIZA MÁS'
        : switch (aim.quality) {
            ThrowQuality.excellent => '¡EXCELENTE!',
            ThrowQuality.great => '¡GENIAL!',
            ThrowQuality.good => '¡BIEN!',
            ThrowQuality.miss => 'FUERA DE OBJETIVO',
          };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: _onPanDown,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: Stack(
        key: _arenaKey,
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: EncounterBackdrop()),
          if (aim != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const Key('encounter-aim-guide'),
                  painter: _AimGuidePainter(
                    from: ball.position,
                    to: aim.impact,
                    color: aimColor,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 14,
            right: 14,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: aimLabel == null
                    ? const SizedBox.shrink(key: Key('aim-label-empty'))
                    : Container(
                        key: ValueKey(aimLabel),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: aimColor, width: 3),
                        ),
                        child: Text(
                          aimLabel,
                          style: textTheme.labelLarge?.copyWith(
                            color: aimColor,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (_step == _Step.absorb)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ImpactPainter(center: _flyTo, progress: _t),
                ),
              ),
            ),
          if (_step == _Step.idle)
            Positioned(
              top: _spriteTop - 13,
              left: _arena.width / 2 - _spriteSize / 2 - 13,
              child: IgnorePointer(
                child: CustomPaint(
                  size: const Size.square(_spriteSize + 26),
                  painter: _CaptureReticlePainter(
                    color: AppColors.accentAlt.withValues(
                      alpha: 0.55 + 0.25 * math.sin(_bob.value * math.pi * 2),
                    ),
                  ),
                ),
              ),
            ),
          // Professor.
          Positioned(
            top: _spriteTop + sprite.offset.dy,
            left: _arena.width / 2 - _spriteSize / 2 + sprite.offset.dx,
            child: IgnorePointer(
              child: Opacity(
                opacity: sprite.opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: sprite.scale,
                  child: Transform.translate(
                    offset: Offset(0, math.sin(_bob.value * 2 * math.pi) * 6),
                    child: ProfessorSprite(
                      key: _spriteKey,
                      professorId: professor.id,
                      spriteUrl: professor.spriteUrl,
                      size: _spriteSize,
                      pose: ProfessorSpritePose.fullBody,
                      transparentBackground: true,
                      semanticLabel: professor.displayName,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Burst rays (success).
          if (_step == _Step.burst)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BurstPainter(
                    center: ball.position,
                    progress: _t,
                    color: AppTheme.rarityColor(professor.rarity),
                  ),
                ),
              ),
            ),
          if (_step == _Step.fly)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ThrowTrailPainter(
                    from: _flyFrom,
                    to: ball.position,
                  ),
                ),
              ),
            ),
          // Instructions.
          if (showInstructions)
            Positioned(
              left: 14,
              right: 14,
              bottom: _ballSize + 30,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Icon(
                      Icons.keyboard_double_arrow_up,
                      color: AppColors.accent,
                      size: 32 + math.sin(_bob.value * 2 * math.pi) * 3,
                    ),
                    RetroDialogue(
                      text: _introLineVisible
                          ? switch (professor.id) {
                              danielRiofrioId => '«$danielRiofrioCatchphrase»',
                              erickNaunayId => erickNaunayIntro,
                              noelPerezId => noelPerezIntro,
                              pavelAlbaId => pavelAlbaIntro,
                              ricardoFloresId => ricardoFloresIntro,
                              joseDavidVegaId => joseDavidVegaIntro,
                              felipeGrijalvaId => felipeGrijalvaIntro,
                              henryCarvajalId => henryCarvajalIntro,
                              diegoMoralesId => diegoMoralesIntro,
                              robertoAndradeId => robertoAndradeIntro,
                              _ => '¡Un nuevo encuentro!',
                            }
                          : 'Desliza hacia arriba y suelta',
                      minHeight: 42,
                    ),
                  ],
                ),
              ),
            ),
          // Ball shadow at rest.
          if (_step == _Step.idle)
            Positioned(
              left: _restPosition.dx - _ballSize * 0.35,
              top: _restPosition.dy + _ballSize / 2 - 4,
              child: IgnorePointer(
                child: Container(
                  width: _ballSize * 0.7,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.shadow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          // Ball.
          if (ball.opacity > 0)
            Positioned(
              left: ball.position.dx - _ballSize / 2,
              top: ball.position.dy - _ballSize / 2,
              child: Opacity(
                opacity: ball.opacity.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: ball.angle,
                  child: Transform.scale(
                    scale: ball.scale,
                    child: const CaptureBall(),
                  ),
                ),
              ),
            ),
          // Status text (quality / capturado / se escapó). Last child of the
          // stack so it paints above the ball and every effect.
          if (_statusText != null)
            Positioned(
              top: _spriteTop + _spriteSize + 12,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Text(
                    _statusText!,
                    key: ValueKey(_statusText),
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      color: _statusColor,
                      // Stacked so the soft halo accumulates opacity.
                      shadows: [
                        for (var i = 0; i < 20; i++)
                          const Shadow(color: Colors.white, blurRadius: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Visual state per step ---------------------------------------------

  ({Offset position, double scale, double angle, double opacity})
  _ballVisual() {
    final t = _t;
    switch (_step) {
      case _Step.idle:
        return (
          position: _ballPos ?? _restPosition,
          scale: _dragging ? 1.08 : 1.0,
          angle: 0,
          opacity: 1,
        );
      case _Step.fly:
        final arc = -math.sin(t * math.pi) * 90;
        return (
          position: Offset.lerp(_flyFrom, _flyTo, t)! + Offset(0, arc),
          scale: 1.0 - 0.35 * t,
          angle: t * 2 * math.pi,
          opacity: 1,
        );
      case _Step.absorb:
        return (position: _flyTo, scale: 0.65 + 0.1 * t, angle: 0, opacity: 1);
      case _Step.drop:
        return (
          position: Offset.lerp(_flyFrom, _flyTo, t)!,
          scale: 0.75,
          angle: 0,
          opacity: 1,
        );
      case _Step.shake:
        return (
          position: _flyTo,
          scale: 0.75,
          angle: math.sin(t * 2 * math.pi) * 0.35,
          opacity: 1,
        );
      case _Step.burst:
        return (
          position: _flyTo,
          scale: 0.75 + 0.6 * t,
          angle: 0,
          opacity: 1 - t,
        );
      case _Step.popOut:
        return (position: _flyTo, scale: 0.75, angle: 0, opacity: 1 - t);
      case _Step.missFly:
        // Straight along the swipe, then gravity pulls it down and it fades.
        final travel = _missDirection * (t * 320);
        final gravity = Offset(0, 260 * t * t);
        return (
          position: _flyFrom + travel + gravity,
          scale: 1.0 - 0.4 * t,
          angle: t * 3 * math.pi,
          opacity: t < 0.75 ? 1 : 1 - (t - 0.75) / 0.25,
        );
      case _Step.dodge:
        return (position: _flyFrom, scale: 0.6, angle: 0, opacity: 0);
    }
  }

  ({Offset offset, double scale, double opacity}) _spriteVisual() {
    final t = _t;
    switch (_step) {
      case _Step.idle:
      case _Step.fly:
      case _Step.missFly:
        return (offset: Offset.zero, scale: 1, opacity: 1);
      case _Step.absorb:
        // Shrinks and slides into the ball.
        final toBall = _flyTo - _spriteRestCenter;
        return (offset: toBall * t, scale: 1 - t, opacity: 1 - t);
      case _Step.drop:
      case _Step.shake:
      case _Step.burst:
        return (offset: Offset.zero, scale: 0, opacity: 0);
      case _Step.popOut:
        return (offset: Offset.zero, scale: t, opacity: t.clamp(0.0, 1.0));
      case _Step.dodge:
        // Little hop to the side: "you missed me".
        final hop = math.sin(t * math.pi);
        return (
          offset: Offset(hop * 36, -hop * 24),
          scale: 1 + hop * 0.08,
          opacity: 1,
        );
    }
  }
}

/// A truthful battle-style gauge: it shows time left, not invented health.
class _EncounterTimeBar extends StatelessWidget {
  const _EncounterTimeBar({required this.fraction, required this.urgent});

  final double fraction;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          Text(
            'TIEMPO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              height: 13,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                border: Border.all(color: AppColors.text, width: 2),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: constraints.maxWidth * fraction.clamp(0.0, 1.0),
                    height: constraints.maxHeight,
                    child: ColoredBox(
                      color: urgent ? AppColors.danger : AppColors.success,
                    ),
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

/// Four pixel corners keep the target visible without covering the portrait.
class _CaptureReticlePainter extends CustomPainter {
  const _CaptureReticlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    const length = 19.0;
    const width = 4.0;
    for (final x in [0.0, size.width - length]) {
      for (final y in [0.0, size.height - length]) {
        final horizontalY = y == 0 ? 0.0 : size.height - width;
        canvas.drawRect(Rect.fromLTWH(x, horizontalY, length, width), paint);
        canvas.drawRect(
          Rect.fromLTWH(x == 0 ? x : size.width - width, y, width, length),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CaptureReticlePainter old) =>
      old.color != color;
}

/// A pixel trail previews the projected hit point while the ball is pulled.
class _AimGuidePainter extends CustomPainter {
  const _AimGuidePainter({
    required this.from,
    required this.to,
    required this.color,
  });

  final Offset from;
  final Offset to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var i = 1; i <= 9; i++) {
      final t = i / 11;
      final point =
          Offset.lerp(from, to, t)! + Offset(0, -math.sin(t * math.pi) * 48);
      paint.color = color.withValues(alpha: 0.22 + i * 0.045);
      canvas.drawRect(
        Rect.fromCenter(center: point, width: 7, height: 7),
        paint,
      );
    }
    paint
      ..color = color.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(Rect.fromCenter(center: to, width: 25, height: 25), paint);
  }

  @override
  bool shouldRepaint(covariant _AimGuidePainter old) =>
      old.from != from || old.to != to || old.color != color;
}

/// Two square shock waves communicate the instant of impact.
class _ImpactPainter extends CustomPainter {
  const _ImpactPainter({required this.center, required this.progress});

  final Offset center;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    for (var i = 0; i < 2; i++) {
      final radius = 24 + progress * 46 + i * 17;
      paint.color = AppColors.accent.withValues(
        alpha: (0.7 - progress * 0.55 - i * 0.14).clamp(0.0, 1.0),
      );
      canvas.drawRect(
        Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactPainter old) =>
      old.center != center || old.progress != progress;
}

/// A few square afterimages make the launch visible even on fast phones.
class _ThrowTrailPainter extends CustomPainter {
  const _ThrowTrailPainter({required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var i = 1; i <= 7; i++) {
      final position = Offset.lerp(from, to, i / 8)!;
      final side = 7.0 + i * 1.3;
      paint.color = const Color(0xFFFFF1A6).withValues(alpha: i / 10);
      canvas.drawRect(
        Rect.fromCenter(center: position, width: side, height: side),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThrowTrailPainter old) =>
      old.from != from || old.to != to;
}

/// Radiating pixel rays + expanding ring for the capture burst.
class _BurstPainter extends CustomPainter {
  const _BurstPainter({
    required this.center,
    required this.progress,
    required this.color,
  });

  final Offset center;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - progress).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    const rays = 12;
    final radius = 40 + progress * 180;
    for (var i = 0; i < rays; i++) {
      final angle = i * 2 * math.pi / rays;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final p = center + dir * radius;
      final s = 8 + 6 * (1 - progress);
      canvas.drawRect(Rect.fromCenter(center: p, width: s, height: s), paint);
    }
    final ring = Paint()
      ..color = AppColors.accent.withValues(alpha: (1 - progress) * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, 30 + progress * 140, ring);
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.progress != progress || old.center != center || old.color != color;
}
