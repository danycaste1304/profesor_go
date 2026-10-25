import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const gameMusicPreferenceKey = 'campus_music_enabled';

enum GameMusicCue { campus, battle, victory }

extension on GameMusicCue {
  String get assetPath => switch (this) {
    GameMusicCue.campus => 'audio/campus_loop.wav',
    // Original chiptune: 'audio/battle_loop.wav'.
    GameMusicCue.battle => 'audio/wild_pokemon_battle.mp3',
    GameMusicCue.victory => 'audio/victory.wav',
  };
}

/// One player owns the soundtrack throughout navigation. A fake can verify
/// route changes without opening an audio device in tests.
abstract class GameMusicPlayer {
  void onComplete(void Function() callback);
  Future<void> play(GameMusicCue cue);
  Future<void> pause();
  Future<void> dispose();
}

class AssetGameMusicPlayer implements GameMusicPlayer {
  AudioPlayer? _player;
  StreamSubscription<void>? _completion;
  void Function()? _onComplete;

  @override
  void onComplete(void Function() callback) => _onComplete = callback;

  @override
  Future<void> play(GameMusicCue cue) async {
    final player = _player ??= AudioPlayer();
    _completion ??= player.onPlayerComplete.listen((_) => _onComplete?.call());
    await player.setReleaseMode(
      cue == GameMusicCue.victory ? ReleaseMode.release : ReleaseMode.loop,
    );
    await player.setVolume(0.22);
    await player.play(AssetSource(cue.assetPath));
  }

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> dispose() async {
    await _completion?.cancel();
    _completion = null;
    final player = _player;
    _player = null;
    await player?.dispose();
  }
}

final gameMusicPlayerProvider = Provider<GameMusicPlayer>(
  (ref) => AssetGameMusicPlayer(),
);

class GameMusicState {
  const GameMusicState({this.enabled = false, this.busy = false});

  final bool enabled;
  final bool busy;
}

/// Kept alive by App, including while the map is not on screen.
final gameMusicControllerProvider =
    NotifierProvider<GameMusicController, GameMusicState>(
      GameMusicController.new,
    );

/// The saved opt-in controls all three original music cues. Route changes
/// share a single audio player, so capture cannot dispose the map soundtrack.
class GameMusicController extends Notifier<GameMusicState>
    with WidgetsBindingObserver {
  late GameMusicPlayer _player;
  Future<void> _operations = Future<void>.value();
  GameMusicCue _cue = GameMusicCue.campus;
  Object? _sceneOwner;
  Timer? _returnToCampus;
  bool _enabled = false;
  bool _inBackground = false;

  @override
  GameMusicState build() {
    _player = ref.read(gameMusicPlayerProvider);
    _player.onComplete(_onTrackComplete);
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _returnToCampus?.cancel();
      WidgetsBinding.instance.removeObserver(this);
      unawaited(
        _operations.then((_) => _player.dispose()).catchError((Object _) {}),
      );
    });
    Future.microtask(_restorePreference);
    return const GameMusicState(busy: true);
  }

  Future<void> _restorePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      _enabled = prefs.getBool(gameMusicPreferenceKey) ?? false;
      if (_enabled) await _syncPlayback();
      if (ref.mounted) state = GameMusicState(enabled: _enabled);
    } catch (_) {
      _enabled = false;
      if (ref.mounted) state = const GameMusicState();
    }
  }

  /// Serializes native player calls so a route change cannot overtake a
  /// previous play/pause request. Each operation reads the latest cue.
  Future<void> _syncPlayback() {
    final operation = _operations.then((_) async {
      if (!ref.mounted) return;
      if (!_enabled || _inBackground) {
        await _player.pause();
      } else {
        await _player.play(_cue);
      }
    });
    _operations = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> enterScene(GameMusicCue cue, Object owner) {
    _returnToCampus?.cancel();
    // A scene already playing this cue hands it over without restarting the
    // track (the scan screen starts the battle music, the encounter keeps it).
    if (_sceneOwner != null && cue == _cue) {
      _sceneOwner = owner;
      return Future<void>.value();
    }
    _sceneOwner = owner;
    _cue = cue;
    return _syncPlayback();
  }

  void leaveScene(Object owner) {
    if (!identical(_sceneOwner, owner)) return;
    _sceneOwner = null;
    // Give the next route a frame to claim its cue. This avoids a brief map
    // note between the battle and victory screens.
    _returnToCampus?.cancel();
    _returnToCampus = Timer(const Duration(milliseconds: 80), () {
      if (!ref.mounted || _sceneOwner != null) return;
      _cue = GameMusicCue.campus;
      unawaited(_syncPlayback().catchError((Object _) {}));
    });
  }

  void _onTrackComplete() {
    if (!ref.mounted || _cue != GameMusicCue.victory) return;
    // The victory jingle is short; continue with the map loop while the
    // player reads the capture result instead of falling silent.
    _cue = GameMusicCue.campus;
    unawaited(_syncPlayback().catchError((Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _inBackground = false;
      unawaited(_syncPlayback().catchError((Object _) {}));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _inBackground = true;
      unawaited(_syncPlayback().catchError((Object _) {}));
    }
  }

  Future<void> toggle() async {
    if (state.busy) return;
    final next = !_enabled;
    state = GameMusicState(enabled: _enabled, busy: true);
    _enabled = next;
    try {
      await _syncPlayback();
      if (ref.mounted) state = GameMusicState(enabled: next);
    } catch (_) {
      _enabled = !next;
      if (ref.mounted) state = GameMusicState(enabled: !next);
      rethrow;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(gameMusicPreferenceKey, next);
    } catch (_) {
      // Playback remains available this session if local storage fails.
    }
  }
}
