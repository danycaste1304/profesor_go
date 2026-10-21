import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the "¡Colección completada!" banner on the map has already been
/// acknowledged in this session (dismissed or opened).
final completionBannerSeenProvider =
    NotifierProvider<CompletionBannerSeen, bool>(CompletionBannerSeen.new);

class CompletionBannerSeen extends Notifier<bool> {
  @override
  bool build() => false;

  void markSeen() => state = true;
}
