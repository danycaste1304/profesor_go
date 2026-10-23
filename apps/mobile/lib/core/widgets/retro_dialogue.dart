import 'package:flutter/material.dart';

/// Square-edged dialogue window with accessible, optional typewriter text.
/// The full message is always exposed to assistive technology.
class RetroDialogue extends StatefulWidget {
  const RetroDialogue({
    super.key,
    required this.text,
    this.animate = true,
    this.minHeight = 76,
  });

  final String text;
  final bool animate;
  final double minHeight;

  @override
  State<RetroDialogue> createState() => _RetroDialogueState();
}

class _RetroDialogueState extends State<RetroDialogue>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<int> _characters;

  @override
  void initState() {
    super.initState();
    _characters = widget.text.runes.toList();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (_characters.length * 27).clamp(1, 4000),
      ),
    );
    if (widget.animate) _controller.forward();
  }

  @override
  void didUpdateWidget(RetroDialogue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text && oldWidget.animate == widget.animate) {
      return;
    }
    _characters = widget.text.runes.toList();
    _controller
      ..duration = Duration(
        milliseconds: (_characters.length * 27).clamp(1, 4000),
      )
      ..reset();
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: widget.text,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF3CC72),
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFF283C4E), width: 3),
            ),
            boxShadow: [
              BoxShadow(color: Color(0x6624364A), offset: Offset(4, 5)),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            decoration: const BoxDecoration(
              color: Color(0xFF265572),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFFFFF8D6), width: 3),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final count = !widget.animate || reduceMotion
                    ? _characters.length
                    : (_controller.value * _characters.length).ceil();
                final visible = String.fromCharCodes(_characters.take(count));
                return Text(
                  visible,
                  style: const TextStyle(
                    color: Color(0xFFFFFAE8),
                    fontSize: 20,
                    height: 1,
                    letterSpacing: 0,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
