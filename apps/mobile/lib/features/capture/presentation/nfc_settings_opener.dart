import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platform channel implemented in `android/app/src/main/kotlin/.../MainActivity.kt`.
/// Android only: iOS has no public NFC settings screen.
const MethodChannel nfcSettingsChannel = MethodChannel('edu.profesorgo/settings');

/// Opens the system NFC settings screen; resolves to false when it could not
/// be opened (unsupported platform, channel missing, no matching activity).
typedef NfcSettingsOpener = Future<bool> Function();

/// Injectable so tests (and the other platforms) never touch the channel.
/// Mirrors `settingsOpenerProvider` of the map feature.
final nfcSettingsOpenerProvider = Provider<NfcSettingsOpener>(
  (ref) => openSystemNfcSettings,
);

/// Whether an "Abrir ajustes de NFC" action makes sense on this platform.
/// Only Android exposes `Settings.ACTION_NFC_SETTINGS`; on iOS (and anywhere
/// the channel is not implemented) the button is hidden instead of failing.
final canOpenNfcSettingsProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

/// Default [NfcSettingsOpener]. Never throws: a missing channel
/// ([MissingPluginException], e.g. an engine without `MainActivity`) or a
/// platform error is reported as `false` so the UI can explain it.
Future<bool> openSystemNfcSettings() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await nfcSettingsChannel.invokeMethod<bool>('openNfcSettings') ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  } catch (_) {
    return false;
  }
}
