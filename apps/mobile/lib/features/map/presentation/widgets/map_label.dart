import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../../../core/widgets/pixel_icon.dart';
import '../../../../core/widgets/pixel_pill.dart';

/// Map marker: an optional [image] stacked on top of an optional [PixelPill]
/// (one column, [imageGap] apart), placed on the campus map. It needs at least
/// one of the two; an image-only label has no text, so give it a
/// [semanticLabel].
///
/// [position] is in logical map units (the 720 x 1290 canvas of
/// [CampusMapConfig], not screen pixels) and marks the **bottom-center** of
/// the label (the base of the image when there is no pill), so it "stands" on
/// the point like a pin. The label must be
/// a direct child of the map's `Stack` (it builds a [Positioned]), inside the
/// zoomable content, so it pans and zooms together with the artwork.
///
/// ### Placing labels by hand (debug only)
/// Labels are fixed unless they opt in with `draggable: MapLabel.dragEnabled`,
/// which makes them draggable in debug builds. When a drag ends the label logs
/// its new position with the [logPrefix], ready to be pasted into code:
///
/// ```text
/// [MapLabel] carpa: Offset(250, 1008)
/// ```
///
/// [dragEnabled] is off in profile and release builds, so a regular build can
/// never move a label (see the app README).
///
/// Once a label's position is final, remove its `draggable` argument.
class MapLabel extends StatefulWidget {
  const MapLabel({
    super.key,
    required this.id,
    required this.position,
    this.label,
    this.semanticLabel,
    this.icon,
    this.color,
    this.tinted = false,
    this.image,
    this.imageHeight = 48,
    this.imageGap = 5,
    this.pillScale = 1,
    this.foreground,
    this.draggable = false,
    this.onMoved,
  }) : assert(label == null || color != null, 'A pill needs a color.'),
       assert(
         label != null || image != null,
         'A MapLabel needs a label, an image, or both.',
       );

  /// Debug switch. Labels are draggable in debug builds (never in profile or
  /// release); `--dart-define=MAP_LABEL_DRAG=false` turns it off for a debug
  /// run, and `=true` forces it on. A label only uses it if it passes
  /// `draggable: MapLabel.dragEnabled`.
  static const bool dragEnabled = bool.fromEnvironment(
    'MAP_LABEL_DRAG',
    defaultValue: kDebugMode,
  );

  /// Prefix of the position log line, so it can be filtered from the
  /// `flutter run` output (e.g. `grep '\[MapLabel\]'`).
  static const String logPrefix = '[MapLabel]';

  /// Stable name used in the position log (e.g. `carpa`, `entrada-lab`).
  final String id;

  /// Bottom-center of the label, in logical map units.
  final Offset position;

  /// Pill text, icon and color; same meaning as in [PixelPill]. Without a
  /// [label] no pill is drawn (an image-only marker).
  final String? label;

  /// Read by screen readers instead of [label]; needed when there is no pill.
  final String? semanticLabel;
  final PixelIconData? icon;
  final Color? color;
  final bool tinted;

  /// Optional picture above the pill (e.g. a pixel-art building). Drawn
  /// without smoothing so pixel art stays crisp when the map is zoomed.
  final ImageProvider? image;

  /// Height of [image] in map units; its width follows the image's ratio.
  final double imageHeight;

  /// Space between [image] and the pill, in map units. Ignored without image.
  final double imageGap;

  /// Size of the pill relative to its normal size (see [PixelPill.scale]);
  /// `1` is 104 x 30 for a text-only pill. The image has its own [imageHeight].
  final double pillScale;

  /// Text / icon color of the pill; see [PixelPill.foreground].
  final Color? foreground;

  /// Whether this label can be dragged (debug tool to place it). Fixed by
  /// default; pass [dragEnabled] to make it draggable in debug builds.
  final bool draggable;

  /// Called with the new [position] when a debug drag ends.
  final ValueChanged<Offset>? onMoved;

  @override
  State<MapLabel> createState() => _MapLabelState();
}

class _MapLabelState extends State<MapLabel> {
  late Offset _position = widget.position;

  @override
  void didUpdateWidget(MapLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new position from code (e.g. after pasting the logged one) wins over
    // the dragged one.
    if (oldWidget.position != widget.position) _position = widget.position;
  }

  void _onDragEnd() {
    final x = _position.dx.toStringAsFixed(0);
    final y = _position.dy.toStringAsFixed(0);
    debugPrint('${MapLabel.logPrefix} ${widget.id}: Offset($x, $y)');
    widget.onMoved?.call(_position);
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.image != null)
          Image(
            image: widget.image!,
            height: widget.imageHeight,
            // Without a fit, Image defaults to scaleDown and never enlarges:
            // a taller imageHeight would only grow the box, not the picture.
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
        if (widget.image != null && widget.label != null)
          SizedBox(height: widget.imageGap * 2),
        if (widget.label != null)
          PixelPill(
            label: widget.label!,
            icon: widget.icon,
            color: widget.color!,
            tinted: widget.tinted,
            scale: widget.pillScale,
            foreground: widget.foreground,
          ),
      ],
    );
    if (widget.semanticLabel != null) {
      content = Semantics(label: widget.semanticLabel, child: content);
    }

    if (widget.draggable) {
      content = GestureDetector(
        // The label is inside the map's zoom transform, so the drag delta
        // already comes in map units: no conversion from screen pixels.
        onPanUpdate: (details) => setState(() => _position += details.delta),
        onPanEnd: (_) => _onDragEnd(),
        child: MouseRegion(cursor: SystemMouseCursors.move, child: content),
      );
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      // Moves the label up and left by its own size so [position] is its
      // bottom-center; hit tests follow the translation.
      child: FractionalTranslation(
        translation: const Offset(-0.5, -1),
        child: content,
      ),
    );
  }
}
