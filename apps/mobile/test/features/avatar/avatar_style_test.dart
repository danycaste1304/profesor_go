import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/features/avatar/avatar_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('decodes older or damaged saved appearances safely', () {
    expect(AvatarStyle.decode('{broken'), const AvatarStyle());
    expect(
      AvatarStyle.decode('{"hair":"curls","outfit":"missing"}'),
      const AvatarStyle(hair: AvatarHair.curls),
    );
  });

  test('saves an appearance for the current player only', () async {
    const first = AuthUser(id: 'avatar-user-1', email: 'one@example.com');
    const second = AuthUser(id: 'avatar-user-2', email: 'two@example.com');

    ProviderContainer forUser(AuthUser user) => ProviderContainer(
      overrides: [currentUserProvider.overrideWithValue(user)],
    );

    final original = forUser(first);
    original.read(avatarStyleProvider);
    await original.read(avatarStyleProvider.notifier).setHair(AvatarHair.curls);
    await original
        .read(avatarStyleProvider.notifier)
        .setOutfit(AvatarOutfit.pink);
    await original
        .read(avatarStyleProvider.notifier)
        .setAccessory(AvatarAccessory.glasses);
    original.dispose();

    final reopened = forUser(first);
    reopened.read(avatarStyleProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      reopened.read(avatarStyleProvider),
      const AvatarStyle(
        hair: AvatarHair.curls,
        outfit: AvatarOutfit.pink,
        accessory: AvatarAccessory.glasses,
      ),
    );
    reopened.dispose();

    final otherPlayer = forUser(second);
    expect(otherPlayer.read(avatarStyleProvider), const AvatarStyle());
    otherPlayer.dispose();
  });

  test(
    'surprise changes the look and persists the complete combination',
    () async {
      const player = AuthUser(
        id: 'surprise-user',
        email: 'surprise@example.com',
      );
      final container = ProviderContainer(
        overrides: [currentUserProvider.overrideWithValue(player)],
      );
      final before = container.read(avatarStyleProvider);
      await container.read(avatarStyleProvider.notifier).surprise();
      final after = container.read(avatarStyleProvider);
      expect(after, isNot(before));
      expect(
        after.outfit != before.outfit || after.accessory != before.accessory,
        isTrue,
      );
      container.dispose();

      final reopened = ProviderContainer(
        overrides: [currentUserProvider.overrideWithValue(player)],
      );
      reopened.read(avatarStyleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reopened.read(avatarStyleProvider), after);
      reopened.dispose();
    },
  );
}
