import 'dart:async';

import '../errors/app_exception.dart';
import '../mock/demo_seed.dart';
import 'nfc_service.dart';

/// A selectable demo card for the scan screen in any demo build.
class DemoTag {
  const DemoTag({
    required this.identifier,
    required this.label,
    this.professorId,
  });

  /// e.g. `DEMO-TAG-01`.
  final String identifier;

  /// Human label, e.g. `Prof. Henry`.
  final String label;
  final String? professorId;

  @override
  bool operator ==(Object other) =>
      other is DemoTag && other.identifier == identifier;

  @override
  int get hashCode => identifier.hashCode;

  @override
  String toString() => 'DemoTag($identifier, $label)';
}

/// In-memory [NfcService]: "scans" [selectedTag] after a short delay.
class MockNfcService implements NfcService {
  MockNfcService({
    this.delay = const Duration(milliseconds: 800),
    List<DemoTag>? tags,
    this._availability = NfcAvailability.available,
  }) : _tags = tags ?? defaultDemoTags() {
    selectedTag = _tags.first;
  }

  final Duration delay;
  final List<DemoTag> _tags;
  NfcAvailability _availability;

  /// The tag the next [scanTag] will return.
  late DemoTag selectedTag;

  Completer<String?>? _pending;
  Timer? _timer;

  /// Selects by identifier (case-insensitive). Unknown identifiers are still
  /// accepted so the "invalid card" flow can be demoed.
  void selectTag(String identifier) {
    final id = identifier.trim();
    selectedTag = _tags.firstWhere(
      (t) => t.identifier.toUpperCase() == id.toUpperCase(),
      orElse: () => DemoTag(identifier: id, label: 'Tarjeta desconocida'),
    );
  }

  /// Simulates enabling / disabling NFC in the device settings.
  set availabilityOverride(NfcAvailability value) => _availability = value;

  Future<List<DemoTag>> demoTags() async => List.unmodifiable(_tags);

  @override
  Future<NfcAvailability> availability() async => _availability;

  @override
  Future<String?> scanTag({void Function()? onReady}) async {
    if (_pending != null) await cancel();
    switch (_availability) {
      case NfcAvailability.unsupported:
        throw AppException.fromCode(AppException.nfcUnsupported);
      case NfcAvailability.disabled:
        throw AppException.fromCode(AppException.nfcDisabled);
      case NfcAvailability.available:
        break;
    }
    final completer = Completer<String?>();
    _pending = completer;
    onReady?.call();
    final tag = selectedTag;
    _timer = Timer(delay, () {
      if (identical(_pending, completer)) {
        _pending = null;
        _timer = null;
        completer.complete(tag.identifier);
      }
    });
    return completer.future;
  }

  @override
  Future<void> cancel() async {
    _timer?.cancel();
    _timer = null;
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.complete(null);
  }

  /// DEMO-TAG-01..08 mapped to the seed professors (CONTRACTS §5).
  static List<DemoTag> defaultDemoTags() => [
    for (final t in demoTagSeeds)
      DemoTag(
        identifier: t.identifier,
        label: demoProfessorById(t.professorId)?.displayName ?? t.identifier,
        professorId: t.professorId,
      ),
  ];
}
