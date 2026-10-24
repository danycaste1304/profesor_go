import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:profesor_go/core/di/providers.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/nfc/mock_nfc_service.dart';
import 'package:profesor_go/core/nfc/nfc_service.dart';
import 'package:profesor_go/core/repositories/capture_service.dart';
import 'package:profesor_go/core/widgets/widgets.dart';
import 'package:profesor_go/features/capture/presentation/nfc_scan_screen.dart';
import 'package:profesor_go/features/capture/presentation/nfc_settings_opener.dart';

import '../fakes.dart';

void main() {
  late FakeCaptureService capture;
  late FakeNfcService nfc;

  setUp(() {
    capture = FakeCaptureService();
    nfc = FakeNfcService();
  });

  GoRouter router() {
    final r = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(path: '/scan', builder: (_, _) => const NfcScanScreen()),
        GoRoute(
          path: '/encounter/:encounterId',
          builder: (_, s) => StubPage(
            'ENCOUNTER ${s.pathParameters['encounterId']} '
            '${(s.extra as Encounter?)?.professor.displayName}',
          ),
        ),
        GoRoute(path: '/map', builder: (_, _) => const StubPage('MAP')),
      ],
    );
    addTearDown(r.dispose);
    return r;
  }

  /// Timed pumps: `LoadingView` (core) schedules zero-length timers that
  /// only fire when fake time advances.
  Future<void> settle(WidgetTester tester, [int times = 3]) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    NfcService? nfcService,
    bool online = true,
    bool? canOpenSettings,
    NfcSettingsOpener? settingsOpener,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nfcServiceProvider.overrideWithValue(nfcService ?? nfc),
          captureServiceProvider.overrideWithValue(capture as CaptureService),
          isOnlineProvider.overrideWithValue(online),
          if (canOpenSettings != null)
            canOpenNfcSettingsProvider.overrideWithValue(canOpenSettings),
          if (settingsOpener != null)
            nfcSettingsOpenerProvider.overrideWithValue(settingsOpener),
        ],
        child: testApp(router: router()),
      ),
    );
    await tester.pump();
  }

  testWidgets('scans DEMO-TAG-01, starts the encounter and navigates', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pump();
    // Availability resolved → scanning UI, session open.
    expect(
      find.text('Acerca tu teléfono a la tarjeta del profesor'),
      findsOneWidget,
    );
    expect(find.byType(CaptureBall), findsOneWidget);
    expect(nfc.scanCalls, 1);
    expect(capture.startedTags, isEmpty);

    // The fake "reads" the card after 20 ms.
    await settle(tester);
    expect(capture.startedTags, ['DEMO-TAG-01']);
    expect(find.text('ENCOUNTER enc-1 Prof. Ricardo'), findsOneWidget);
  });

  testWidgets('waits for reader mode before inviting the player to scan', (
    tester,
  ) async {
    final manualNfc = _ManualReadyNfcService();
    await pumpScreen(tester, nfcService: manualNfc);
    await settle(tester);

    expect(manualNfc._onReady, isNotNull);
    expect(find.text('Comprobando el NFC…'), findsOneWidget);
    expect(find.text('BUSCANDO TARJETA'), findsNothing);

    manualNfc.markReady();
    await tester.pump();
    expect(find.text('BUSCANDO TARJETA'), findsOneWidget);
    expect(
      find.text('Acerca tu teléfono a la tarjeta del profesor'),
      findsOneWidget,
    );
  });

  testWidgets('ALREADY_CAPTURED shows the Spanish message and retries', (
    tester,
  ) async {
    capture.startError = AppException.fromCode(AppException.alreadyCaptured);
    await pumpScreen(tester);
    await settle(tester);

    expect(find.text('Ya capturaste a este profesor'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
    expect(capture.startedTags, hasLength(1));

    // Retry starts a new scan session.
    capture.startError = null;
    await tester.tap(find.text('REINTENTAR'));
    await tester.pump();
    await tester.pump();
    expect(nfc.scanCalls, 2);
    await settle(tester);
    expect(capture.startedTags, hasLength(2));
    expect(find.textContaining('ENCOUNTER enc-1'), findsOneWidget);
  });

  testWidgets('maps TAG_NOT_FOUND / TAG_DISABLED / PROFESSOR_DISABLED', (
    tester,
  ) async {
    for (final code in [
      AppException.tagNotFound,
      AppException.tagDisabled,
      AppException.professorDisabled,
    ]) {
      capture = FakeCaptureService(startError: AppException.fromCode(code));
      nfc = FakeNfcService();
      await pumpScreen(tester);
      await settle(tester);
      expect(
        find.text(AppException.messages[code]!),
        findsOneWidget,
        reason: code,
      );
      expect(find.text('REINTENTAR'), findsOneWidget);
    }
  });

  testWidgets('unsupported device shows the friendly message', (tester) async {
    nfc.availabilityValue = NfcAvailability.unsupported;
    await pumpScreen(tester);
    await settle(tester);
    expect(find.text('Este dispositivo no tiene NFC'), findsOneWidget);
    expect(nfc.scanCalls, 0);
  });

  testWidgets('disabled NFC asks to enable it and can retry', (tester) async {
    nfc.availabilityValue = NfcAvailability.disabled;
    await pumpScreen(tester);
    await settle(tester);
    expect(find.text('Activa el NFC en los ajustes'), findsOneWidget);
    expect(nfc.scanCalls, 0);

    nfc.availabilityValue = NfcAvailability.available;
    nfc.scanDelay = const Duration(seconds: 30);
    await tester.tap(find.text('REINTENTAR'));
    await settle(tester);
    expect(nfc.scanCalls, 1);
    expect(
      find.text('Acerca tu teléfono a la tarjeta del profesor'),
      findsOneWidget,
    );
  });

  testWidgets('disabled NFC offers to open the Android NFC settings', (
    tester,
  ) async {
    var calls = 0;
    // Narrow phone: both actions must still fit without overflowing.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    nfc.availabilityValue = NfcAvailability.disabled;
    await pumpScreen(
      tester,
      canOpenSettings: true,
      settingsOpener: () async {
        calls++;
        return true;
      },
    );
    await settle(tester);

    expect(find.text('Activa el NFC en los ajustes'), findsOneWidget);
    expect(find.text('ABRIR AJUSTES DE NFC'), findsOneWidget);

    await tester.tap(find.text('ABRIR AJUSTES DE NFC'));
    await settle(tester);
    expect(calls, 1);
    // Opening the settings does not disturb the screen (no scan, no snackbar).
    expect(nfc.scanCalls, 0);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an unavailable settings channel explains it instead of crashing',
    (tester) async {
      nfc.availabilityValue = NfcAvailability.disabled;
      await pumpScreen(
        tester,
        canOpenSettings: true,
        // What `openSystemNfcSettings` returns on MissingPluginException.
        settingsOpener: () async => false,
      );
      await settle(tester);

      await tester.tap(find.text('ABRIR AJUSTES DE NFC'));
      await settle(tester);
      expect(
        find.textContaining('No se pudieron abrir los ajustes de NFC'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hides the settings button where NFC settings cannot be opened', (
    tester,
  ) async {
    nfc.availabilityValue = NfcAvailability.disabled;
    await pumpScreen(tester, canOpenSettings: false); // e.g. iOS
    await settle(tester);

    expect(find.text('Activa el NFC en los ajustes'), findsOneWidget);
    expect(find.text('ABRIR AJUSTES DE NFC'), findsNothing);
    expect(find.text('REINTENTAR'), findsOneWidget);
  });

  testWidgets('offline shows the no-internet message and does not scan', (
    tester,
  ) async {
    await pumpScreen(tester, online: false);
    await settle(tester);
    expect(
      find.text(AppException.messages[AppException.noInternet]!),
      findsOneWidget,
    );
    expect(find.text('REINTENTAR'), findsOneWidget);
    expect(nfc.scanCalls, 0);
  });

  testWidgets('a cancelled / timed-out scan offers a retry', (tester) async {
    nfc.tag = null;
    await pumpScreen(tester);
    await settle(tester);
    expect(
      find.textContaining('No se detectó ninguna tarjeta'),
      findsOneWidget,
    );
    expect(find.text('REINTENTAR'), findsOneWidget);
    expect(capture.startedTags, isEmpty);
  });

  testWidgets('demo picker lists the demo tags and starts the chosen one', (
    tester,
  ) async {
    // DEMO_MODE works without NFC in both debug and release builds.
    final mock = MockNfcService(delay: const Duration(seconds: 5));
    await pumpScreen(tester, nfcService: mock);
    await settle(tester);
    expect(find.text('TARJETAS DEMO'), findsOneWidget);
    expect(find.text('Elige una tarjeta demo'), findsOneWidget);
    expect(find.text('Prof. Henry'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(capture.startedTags, isEmpty);

    await tester.ensureVisible(find.text('Prof. Erick'));
    await settle(tester);
    await tester.tap(find.text('Prof. Erick'));
    await settle(tester);
    expect(capture.startedTags, ['DEMO-TAG-08']);
    expect(mock.selectedTag.identifier, 'DEMO-TAG-08');
    expect(find.textContaining('ENCOUNTER enc-1'), findsOneWidget);
  });

  testWidgets('cancels the NFC session on dispose', (tester) async {
    nfc.scanDelay = const Duration(seconds: 30);
    await pumpScreen(tester);
    await settle(tester);
    expect(nfc.scanCalls, 1);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await settle(tester);
    expect(nfc.cancelCalls, greaterThanOrEqualTo(2)); // begin() + dispose()
    expect(capture.startedTags, isEmpty);
  });
}

class _ManualReadyNfcService implements NfcService {
  void Function()? _onReady;
  Completer<String?>? _pending;

  @override
  Future<NfcAvailability> availability() async => NfcAvailability.available;

  @override
  Future<String?> scanTag({void Function()? onReady}) {
    _onReady = onReady;
    return (_pending = Completer<String?>()).future;
  }

  void markReady() => _onReady?.call();

  @override
  Future<void> cancel() async {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(null);
  }
}
