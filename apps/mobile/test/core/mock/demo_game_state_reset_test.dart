import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/mock/demo_game_state.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reset clears only demo captures and survives app restart', () async {
    SharedPreferences.setMockInitialValues({
      'campus_music_enabled': true,
      'player_avatar_style_v1_demo-user': 'saved-avatar',
    });
    final state = DemoGameState(persist: true);
    await state.ensureLoaded();
    await state.addCapture(
      Capture(
        id: 'demo-reset-capture',
        userId: state.userId,
        professorId: demoProfessors.first.id,
        throwQuality: ThrowQuality.great,
        capturedAt: DateTime.utc(2026, 10, 20),
      ),
    );
    expect(state.captures, hasLength(1));

    await state.reset();

    final reopened = DemoGameState(persist: true);
    await reopened.ensureLoaded();
    expect(reopened.captures, isEmpty);
    expect(reopened.progress().captured, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('campus_music_enabled'), isTrue);
    expect(prefs.getString('player_avatar_style_v1_demo-user'), 'saved-avatar');
  });
}
