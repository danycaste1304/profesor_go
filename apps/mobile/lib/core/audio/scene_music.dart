import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_music_controller.dart';

enum SceneMusicCue { battle, victory }

/// Claims a music cue while this route is visible. The player itself lives in
/// GameMusicController and continues when this widget leaves the tree.
class SceneMusic extends ConsumerStatefulWidget {
  const SceneMusic({super.key, required this.cue, required this.child});

  final SceneMusicCue cue;
  final Widget child;

  @override
  ConsumerState<SceneMusic> createState() => _SceneMusicState();
}

class _SceneMusicState extends ConsumerState<SceneMusic> {
  final Object _owner = Object();
  late final GameMusicController _music;

  GameMusicCue get _cue => switch (widget.cue) {
    SceneMusicCue.battle => GameMusicCue.battle,
    SceneMusicCue.victory => GameMusicCue.victory,
  };

  @override
  void initState() {
    super.initState();
    _music = ref.read(gameMusicControllerProvider.notifier);
    unawaited(_music.enterScene(_cue, _owner).catchError((Object _) {}));
  }

  @override
  void didUpdateWidget(SceneMusic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cue != widget.cue) {
      unawaited(_music.enterScene(_cue, _owner).catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    _music.leaveScene(_owner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
