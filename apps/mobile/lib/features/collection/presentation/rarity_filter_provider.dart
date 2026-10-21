import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/rarity.dart';

/// Selected rarity chip on the collection screen (`null` = "Todos").
class RarityFilterNotifier extends Notifier<Rarity?> {
  @override
  Rarity? build() => null;

  void select(Rarity? rarity) => state = rarity;
}

final rarityFilterProvider = NotifierProvider<RarityFilterNotifier, Rarity?>(
  RarityFilterNotifier.new,
);
