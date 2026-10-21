import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_music_controller.dart';

enum EncounterSound { throwBall, impact, shake, success, escape }

extension on EncounterSound {
  String get assetName => switch (this) {
    EncounterSound.throwBall => 'throw.wav',
    EncounterSound.impact => 'impact.wav',
    EncounterSound.shake => 'shake.wav',
    EncounterSound.success => 'success.wav',
    EncounterSound.escape => 'escape.wav',
  };
}

/// One route-owned player for the short, original capture cues.
/// Cues never delay the throw or its backend result if audio is unavailable.
class EncounterSoundEffects {
  AudioPlayer? _player;
  Future<bool>? _enabled;
  Future<void> _queue = Future<void>.value();
  bool _ready = false;
  bool _hasPlayed = false;
  bool _disposed = false;

  void play(EncounterSound cue) {
    if (_disposed) return;
    _queue = _queue.then((_) => _play(cue));
  }

  Future<bool> _soundEnabled() => _enabled ??= () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(gameMusicPreferenceKey) ?? false;
    } catch (_) {
      return false;
    }
  }();

  Future<void> _play(EncounterSound cue) async {
    try {
      if (_disposed || !await _soundEnabled() || _disposed) return;
      final player = _player ??= AudioPlayer();
      if (!_ready) {
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              audioFocus: AndroidAudioFocus.none,
            ),
            iOS: AudioContextIOS(
              options: {AVAudioSessionOptions.mixWithOthers},
            ),
          ),
        );
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(0.38);
        _ready = true;
      }
      if (_disposed) return;
      if (_hasPlayed) await player.stop();
      if (_disposed) return;
      await player.play(AssetSource('audio/${cue.assetName}'));
      _hasPlayed = true;
    } catch (error) {
      // Silent mode, missing audio hardware and plugin errors are non-fatal.
      if (kDebugMode) debugPrint('encounter sound unavailable: $error');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _queue;
    final player = _player;
    _player = null;
    try {
      await player?.dispose();
    } catch (_) {
      // Leaving a scene must not surface an optional audio error.
    }
  }
}
