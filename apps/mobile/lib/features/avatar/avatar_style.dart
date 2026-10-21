import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/providers.dart';

enum AvatarHair { short, curls, ponytail }

enum AvatarOutfit { turquoise, pink, lilac }

enum AvatarAccessory { cap, glasses, bow }

/// Small, device-local cosmetic choice. IDs are stored per signed-in player so
/// changing accounts on one device does not change another player's trainer.
class AvatarStyle {
  const AvatarStyle({
    this.hair = AvatarHair.short,
    this.outfit = AvatarOutfit.turquoise,
    this.accessory = AvatarAccessory.cap,
  });

  final AvatarHair hair;
  final AvatarOutfit outfit;
  final AvatarAccessory accessory;

  AvatarStyle copyWith({
    AvatarHair? hair,
    AvatarOutfit? outfit,
    AvatarAccessory? accessory,
  }) => AvatarStyle(
    hair: hair ?? this.hair,
    outfit: outfit ?? this.outfit,
    accessory: accessory ?? this.accessory,
  );

  String encode() => jsonEncode({
    'hair': hair.name,
    'outfit': outfit.name,
    'accessory': accessory.name,
  });

  static AvatarStyle decode(String? value) {
    if (value == null) return const AvatarStyle();
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      T choice<T extends Enum>(List<T> options, Object? name, T fallback) {
        for (final option in options) {
          if (option.name == name) return option;
        }
        return fallback;
      }

      return AvatarStyle(
        hair: choice(AvatarHair.values, data['hair'], AvatarHair.short),
        outfit: choice(
          AvatarOutfit.values,
          data['outfit'],
          AvatarOutfit.turquoise,
        ),
        accessory: choice(
          AvatarAccessory.values,
          data['accessory'],
          AvatarAccessory.cap,
        ),
      );
    } catch (_) {
      return const AvatarStyle();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarStyle &&
      hair == other.hair &&
      outfit == other.outfit &&
      accessory == other.accessory;

  @override
  int get hashCode => Object.hash(hair, outfit, accessory);
}

final avatarStyleProvider =
    NotifierProvider<AvatarStyleController, AvatarStyle>(
      AvatarStyleController.new,
    );

class AvatarStyleController extends Notifier<AvatarStyle> {
  String _key = '';
  int _revision = 0;
  Future<void> _writes = Future<void>.value();

  @override
  AvatarStyle build() {
    final userId = ref.watch(currentUserProvider)?.id ?? 'guest';
    _key = 'player_avatar_style_v1_$userId';
    final revision = ++_revision;
    Future.microtask(() => _restore(_key, revision));
    return const AvatarStyle();
  }

  Future<void> _restore(String key, int revision) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (ref.mounted && _key == key && _revision == revision) {
        state = AvatarStyle.decode(prefs.getString(key));
      }
    } catch (_) {
      // Default appearance remains usable if local storage is unavailable.
    }
  }

  Future<void> setHair(AvatarHair value) => _set(state.copyWith(hair: value));
  Future<void> setOutfit(AvatarOutfit value) =>
      _set(state.copyWith(outfit: value));
  Future<void> setAccessory(AvatarAccessory value) =>
      _set(state.copyWith(accessory: value));

  /// A surprise visibly changes the outfit or accessory, and saves all three
  /// choices at once so the preview and map remain in sync.
  Future<void> surprise() {
    final choices =
        [
          for (final hair in AvatarHair.values)
            for (final outfit in AvatarOutfit.values)
              for (final accessory in AvatarAccessory.values)
                AvatarStyle(hair: hair, outfit: outfit, accessory: accessory),
        ]..removeWhere(
          (choice) =>
              choice.outfit == state.outfit &&
              choice.accessory == state.accessory,
        );
    return _set(choices[Random().nextInt(choices.length)]);
  }

  Future<void> _set(AvatarStyle next) {
    if (next == state) return Future<void>.value();
    state = next;
    ++_revision;
    final key = _key;
    final encoded = next.encode();
    // Preserve tap order when a player changes several choices quickly.
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, encoded);
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}
