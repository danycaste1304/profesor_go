import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/features/capture/presentation/nfc_settings_opener.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void mockChannel(Future<Object?>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(nfcSettingsChannel, (call) {
      calls.add(call);
      return handler(call);
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(nfcSettingsChannel, null),
    );
  }

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('calls openNfcSettings on the Android channel', () async {
    mockChannel((_) async => true);
    expect(await openSystemNfcSettings(), isTrue);
    expect(calls.single.method, 'openNfcSettings');
  });

  test('a false result (no settings activity) is reported as false', () async {
    mockChannel((_) async => false);
    expect(await openSystemNfcSettings(), isFalse);
  });

  test('a null result is reported as false', () async {
    mockChannel((_) async => null);
    expect(await openSystemNfcSettings(), isFalse);
  });

  test('MissingPluginException does not escape', () async {
    // No handler registered → the channel is not implemented.
    expect(await openSystemNfcSettings(), isFalse);
  });

  test('PlatformException does not escape', () async {
    mockChannel((_) async => throw PlatformException(code: 'BOOM'));
    expect(await openSystemNfcSettings(), isFalse);
  });

  test('non-Android platforms never touch the channel', () async {
    mockChannel((_) async => true);
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(await openSystemNfcSettings(), isFalse, reason: '$platform');
    }
    expect(calls, isEmpty);
  });
}
