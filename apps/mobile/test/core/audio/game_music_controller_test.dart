import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/audio/game_music_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeMusicPlayer implements GameMusicPlayer {
  final List<GameMusicCue> cues = [];
  int pauses = 0;
  int disposals = 0;
  bool failPlay = false;
  void Function()? complete;

  @override
  void onComplete(void Function() callback) => complete = callback;

  @override
  Future<void> play(GameMusicCue cue) async {
    if (failPlay) throw StateError('No audio device');
    cues.add(cue);
  }

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> dispose() async => disposals++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'music is opt-in, toggles playback and restores the saved choice',
    () async {
      final firstPlayer = FakeMusicPlayer();
      final first = ProviderContainer(
        overrides: [gameMusicPlayerProvider.overrideWithValue(firstPlayer)],
      );
      first.listen(gameMusicControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(first.read(gameMusicControllerProvider).enabled, false);
      expect(firstPlayer.cues, isEmpty);

      await first.read(gameMusicControllerProvider.notifier).toggle();
      expect(first.read(gameMusicControllerProvider).enabled, true);
      expect(firstPlayer.cues, [GameMusicCue.campus]);
      expect(
        (await SharedPreferences.getInstance()).getBool('campus_music_enabled'),
        true,
      );
      first.dispose();

      final restoredPlayer = FakeMusicPlayer();
      final restored = ProviderContainer(
        overrides: [gameMusicPlayerProvider.overrideWithValue(restoredPlayer)],
      );
      restored.listen(gameMusicControllerProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(restored.read(gameMusicControllerProvider).enabled, true);
      expect(restoredPlayer.cues, [GameMusicCue.campus]);

      await restored.read(gameMusicControllerProvider.notifier).toggle();
      expect(restored.read(gameMusicControllerProvider).enabled, false);
      expect(restoredPlayer.pauses, 1);
      expect(
        (await SharedPreferences.getInstance()).getBool('campus_music_enabled'),
        false,
      );
      restored.dispose();
    },
  );

  test('playback failure leaves music off and does not save opt-in', () async {
    final player = FakeMusicPlayer()..failPlay = true;
    final container = ProviderContainer(
      overrides: [gameMusicPlayerProvider.overrideWithValue(player)],
    );
    container.listen(gameMusicControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      container.read(gameMusicControllerProvider.notifier).toggle(),
      throwsStateError,
    );
    expect(container.read(gameMusicControllerProvider).enabled, false);
    expect(
      (await SharedPreferences.getInstance()).getBool('campus_music_enabled'),
      null,
    );
    container.dispose();
  });

  test(
    'music player lives past map listeners and is released with app',
    () async {
      final player = FakeMusicPlayer();
      final container = ProviderContainer(
        overrides: [gameMusicPlayerProvider.overrideWithValue(player)],
      );
      final subscription = container.listen(
        gameMusicControllerProvider,
        (_, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      await container.read(gameMusicControllerProvider.notifier).toggle();
      expect(player.cues, [GameMusicCue.campus]);

      subscription.close();
      await container.pump();
      expect(player.disposals, 0);
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(player.disposals, 1);
    },
  );

  test(
    'capture music flows from battle to victory to map without silence',
    () async {
      SharedPreferences.setMockInitialValues({gameMusicPreferenceKey: true});
      final player = FakeMusicPlayer();
      final container = ProviderContainer(
        overrides: [gameMusicPlayerProvider.overrideWithValue(player)],
      );
      container.listen(gameMusicControllerProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(player.cues, [GameMusicCue.campus]);

      final music = container.read(gameMusicControllerProvider.notifier);
      final encounter = Object();
      final result = Object();
      await music.enterScene(GameMusicCue.battle, encounter);
      await music.enterScene(GameMusicCue.victory, result);
      music.leaveScene(encounter); // The old route cannot interrupt victory.
      expect(player.cues, [
        GameMusicCue.campus,
        GameMusicCue.battle,
        GameMusicCue.victory,
      ]);

      player.complete?.call(); // End of the short victory fanfare.
      await Future<void>.delayed(Duration.zero);
      expect(player.cues.last, GameMusicCue.campus);
      expect(player.pauses, 0);
      expect(container.read(gameMusicControllerProvider).enabled, true);
      container.dispose();
    },
  );

  test(
    'the encounter takes over the battle music without restarting it',
    () async {
      SharedPreferences.setMockInitialValues({gameMusicPreferenceKey: true});
      final player = FakeMusicPlayer();
      final container = ProviderContainer(
        overrides: [gameMusicPlayerProvider.overrideWithValue(player)],
      );
      container.listen(gameMusicControllerProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final music = container.read(gameMusicControllerProvider.notifier);
      final scan = Object();
      final encounter = Object();
      await music.enterScene(GameMusicCue.battle, scan); // wipe starts
      await music.enterScene(GameMusicCue.battle, encounter); // route opens
      music.leaveScene(scan); // old route disposed: no longer the owner
      await Future<void>.delayed(const Duration(milliseconds: 110));
      expect(player.cues, [GameMusicCue.campus, GameMusicCue.battle]);
      container.dispose();
    },
  );

  test('an escaped professor returns the soundtrack to the map', () async {
    SharedPreferences.setMockInitialValues({gameMusicPreferenceKey: true});
    final player = FakeMusicPlayer();
    final container = ProviderContainer(
      overrides: [gameMusicPlayerProvider.overrideWithValue(player)],
    );
    container.listen(gameMusicControllerProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final music = container.read(gameMusicControllerProvider.notifier);
    final encounter = Object();
    await music.enterScene(GameMusicCue.battle, encounter);
    music.leaveScene(encounter);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    expect(player.cues.last, GameMusicCue.campus);
    expect(container.read(gameMusicControllerProvider).enabled, true);
    container.dispose();
  });
}
