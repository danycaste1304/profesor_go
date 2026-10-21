import '../../../core/models/collection_progress.dart';
import '../../../core/models/professor.dart';
import '../../../core/models/throw_quality.dart';

/// Typed `extra` for the `/result` route:
/// `context.go(AppRoutes.result, extra: CaptureResultArgs(...))`.
class CaptureResultArgs {
  const CaptureResultArgs({
    required this.professor,
    required this.success,
    this.collection,
    this.quality,
  });

  final ProfessorSummary professor;
  final bool success;

  /// Progress after a successful capture (null on failure).
  final CollectionProgress? collection;

  /// The throw that produced this result (optional, for the result copy).
  final ThrowQuality? quality;

  bool get collectionCompleted => collection?.completed ?? false;

  @override
  String toString() =>
      'CaptureResultArgs(${professor.displayName}, success=$success, $collection)';
}
