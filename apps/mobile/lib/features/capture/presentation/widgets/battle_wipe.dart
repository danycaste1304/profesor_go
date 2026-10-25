import 'dart:async';

import 'package:flutter/widgets.dart';

/// Pokémon-style "battle wipe" between the scan and the encounter: black
/// horizontal bars slide in, alternating from the left and the right, until
/// the screen is covered; the encounter route is opened underneath; then the
/// bars slide back out the way they came.
///
/// Everything about the effect lives in this file. It runs in the root
/// [Overlay], above every route, so the router keeps its normal transitions.
///
/// To tweak it, edit the constants below. To switch it off, set [enabled] to
/// `false`: [play] then navigates at once and [introDelay] becomes zero. To
/// remove it, delete this file and its two call sites (the scan screen's
/// [play] and the encounter's [introDelay]).
abstract final class BattleWipe {
  /// Master switch for the whole effect.
  static const bool enabled = true;

  /// Number of horizontal bars that cover the screen.
  static const int barCount = 10;

  /// Bar widths snap to this size so the leading edges move in pixel steps.
  static const double block = 8;

  /// Bars sliding in until the screen is black.
  static const Duration cover = Duration(milliseconds: 700);

  /// Fully black pause; the encounter is opened at its start.
  static const Duration hold = Duration(milliseconds: 100);

  /// Bars sliding back out to reveal the encounter.
  static const Duration reveal = Duration(milliseconds: 600);

  /// How much later each bar starts than the previous one, as a fraction of
  /// [cover] / [reveal]. `0` moves every bar together.
  static const double stagger = 0.06;

  static const Color color = Color(0xFF000000);

  /// Time from opening the encounter until the screen is fully revealed. The
  /// encounter waits this long before its intro dialogue.
  static Duration get introDelay => enabled ? hold + reveal : Duration.zero;

  /// Covers the screen, calls [onCovered] (navigate there), then reveals the
  /// new screen. Touches are blocked while it runs. Completes when the bars
  /// are gone.
  static Future<void> play(
    BuildContext context, {
    required VoidCallback onCovered,
  }) {
    if (!enabled) {
      onCovered();
      return Future<void>.value();
    }
    final done = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BattleWipeOverlay(
        onCovered: onCovered,
        onDone: () {
          entry.remove();
          done.complete();
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    return done.future;
  }
}

class _BattleWipeOverlay extends StatefulWidget {
  const _BattleWipeOverlay({required this.onCovered, required this.onDone});

  final VoidCallback onCovered;
  final VoidCallback onDone;

  @override
  State<_BattleWipeOverlay> createState() => _BattleWipeOverlayState();
}

class _BattleWipeOverlayState extends State<_BattleWipeOverlay>
    with SingleTickerProviderStateMixin {
  static final Duration _total =
      BattleWipe.cover + BattleWipe.hold + BattleWipe.reveal;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  );
  bool _covered = false;

  double _fraction(Duration d) => d.inMicroseconds / _total.inMicroseconds;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  void _onTick() {
    if (!_covered && _controller.value >= _fraction(BattleWipe.cover)) {
      _covered = true;
      widget.onCovered();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final coverEnd = _fraction(BattleWipe.cover);
            final revealStart = _fraction(BattleWipe.cover + BattleWipe.hold);
            final BattleWipePainter painter;
            if (t < coverEnd) {
              painter = BattleWipePainter(progress: t / coverEnd);
            } else if (t < revealStart) {
              painter = const BattleWipePainter(progress: 1);
            } else {
              painter = BattleWipePainter(
                progress: (t - revealStart) / (1 - revealStart),
                revealing: true,
              );
            }
            return CustomPaint(painter: painter);
          },
        ),
      ),
    );
  }
}

/// Paints the bars of [BattleWipe]. Even bars come from the left, odd bars
/// from the right. While covering, [progress] 0 → 1 slides them in; while
/// [revealing], 0 → 1 slides them back out toward the side they came from.
class BattleWipePainter extends CustomPainter {
  const BattleWipePainter({required this.progress, this.revealing = false});

  final double progress;
  final bool revealing;

  /// Covered fraction (0-1) of bar [index], before snapping to blocks.
  static double barCoverage(
    int index,
    double progress, {
    bool revealing = false,
  }) {
    const n = BattleWipe.barCount;
    const span = 1 - (n - 1) * BattleWipe.stagger;
    final local = ((progress - index * BattleWipe.stagger) / span).clamp(
      0.0,
      1.0,
    );
    return revealing ? 1 - local : local;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BattleWipe.color
      ..isAntiAlias = false;
    const n = BattleWipe.barCount;
    for (var i = 0; i < n; i++) {
      final coverage = barCoverage(i, progress, revealing: revealing);
      // Round up to whole blocks so a fully covered bar reaches the edge.
      final width =
          ((coverage * size.width) / BattleWipe.block).ceil() *
          BattleWipe.block;
      if (width <= 0) continue;
      // Floor / ceil the edges so neighbouring bars never leave a gap.
      final top = (i * size.height / n).floorToDouble();
      final bottom = ((i + 1) * size.height / n).ceilToDouble();
      final left = i.isEven ? 0.0 : size.width - width;
      canvas.drawRect(Rect.fromLTRB(left, top, left + width, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(BattleWipePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.revealing != revealing;
}
