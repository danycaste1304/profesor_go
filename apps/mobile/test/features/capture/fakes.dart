import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:profesor_go/app/theme.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/mock/demo_seed.dart';
import 'package:profesor_go/core/models/models.dart';
import 'package:profesor_go/core/nfc/nfc_service.dart';
import 'package:profesor_go/core/repositories/capture_service.dart';

/// Hand-written [CaptureService] fake with recorded calls.
class FakeCaptureService extends CaptureService {
  FakeCaptureService({
    this.encounter,
    this.result = const CaptureResult.failed(),
    this.resolveError,
    this.startError,
  });

  /// Returned by [startEncounter] (a default one is built when null).
  Encounter? encounter;
  CaptureResult result;
  AppException? resolveError;
  AppException? startError;

  /// When set, [resolveCapture] waits for it before answering.
  Completer<void>? resolveGate;

  final List<String> startedTags = [];
  final List<({String encounterId, ThrowQuality quality})> resolved = [];

  /// Puts [e] in the session cache (like a real `startEncounter` would).
  void remember(Encounter e) => rememberEncounter(e);

  @override
  Future<Encounter> startEncounter(String tagIdentifier) async {
    startedTags.add(tagIdentifier);
    final error = startError;
    if (error != null) throw error;
    final e = encounter ?? makeEncounter();
    rememberEncounter(e);
    return e;
  }

  @override
  Future<CaptureResult> resolveCapture({
    required String encounterId,
    required ThrowQuality quality,
  }) async {
    resolved.add((encounterId: encounterId, quality: quality));
    final gate = resolveGate;
    if (gate != null) await gate.future;
    final error = resolveError;
    if (error != null) throw error;
    return result;
  }
}

/// [NfcService] fake: resolves [tag] after [scanDelay] (fake time).
class FakeNfcService implements NfcService {
  FakeNfcService({
    this.tag = 'DEMO-TAG-01',
    this.availabilityValue = NfcAvailability.available,
    this.scanError,
    this.scanDelay = const Duration(milliseconds: 20),
  });

  String? tag;
  NfcAvailability availabilityValue;
  AppException? scanError;
  Duration scanDelay;

  int scanCalls = 0;
  int cancelCalls = 0;
  Completer<String?>? _pending;
  Timer? _timer;

  @override
  Future<NfcAvailability> availability() async => availabilityValue;

  @override
  Future<String?> scanTag() {
    scanCalls++;
    final error = scanError;
    if (error != null) return Future.error(error);
    final completer = Completer<String?>();
    _pending = completer;
    _timer = Timer(scanDelay, () {
      if (identical(_pending, completer)) {
        _pending = null;
        completer.complete(tag);
      }
    });
    return completer.future;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    _timer?.cancel();
    _timer = null;
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.complete(null);
  }
}

/// A demo-seed based encounter (Prof. Ricardo, RARE) valid for [ttl].
Encounter makeEncounter({
  String id = 'enc-1',
  Duration ttl = const Duration(minutes: 3),
  DateTime? now,
  EncounterStatus status = EncounterStatus.active,
}) => Encounter(
  id: id,
  expiresAt: (now ?? DateTime.now()).toUtc().add(ttl),
  professor: demoProfessors[3].summary,
  status: status,
);

/// `MaterialApp.router` with the app theme (wrap it in a `ProviderScope`).
Widget testApp({required GoRouter router}) => MaterialApp.router(
  theme: AppTheme.dark(),
  darkTheme: AppTheme.dark(),
  themeMode: ThemeMode.dark,
  routerConfig: router,
);

/// Minimal page used as a navigation target in tests.
class StubPage extends StatelessWidget {
  const StubPage(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

/// Pumps in [step]s until [finder] matches or [timeout] elapses (fake time).
/// Returns whether it matched. [onStep] runs after every pump.
Future<bool> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 8),
  Duration step = const Duration(milliseconds: 50),
  void Function()? onStep,
}) async {
  var elapsed = Duration.zero;
  while (elapsed < timeout) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.pump(step);
    onStep?.call();
    elapsed += step;
  }
  return finder.evaluate().isNotEmpty;
}
