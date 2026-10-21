import 'collection_progress.dart';

/// Response of `resolve-capture` (CONTRACTS §4).
///
/// Success: `{success: true, professor_id, collection}`.
/// Failure: `{success: false, retry_requires_new_nfc_scan: true}`.
class CaptureResult {
  const CaptureResult({
    required this.success,
    this.professorId,
    this.collection,
    this.retryRequiresNewNfcScan = true,
  });

  factory CaptureResult.fromJson(Map<String, dynamic> json) {
    final success = json['success'] as bool? ?? false;
    final collection = json['collection'];
    return CaptureResult(
      success: success,
      professorId: json['professor_id'] as String?,
      collection: collection is Map
          ? CollectionProgress.fromJson(collection.cast<String, dynamic>())
          : null,
      retryRequiresNewNfcScan:
          json['retry_requires_new_nfc_scan'] as bool? ?? !success,
    );
  }

  const CaptureResult.failed()
      : success = false,
        professorId = null,
        collection = null,
        retryRequiresNewNfcScan = true;

  final bool success;
  final String? professorId;
  final CollectionProgress? collection;

  /// After a failed throw the encounter is over: the player must scan again.
  final bool retryRequiresNewNfcScan;

  Map<String, dynamic> toJson() => success
      ? {
          'success': true,
          'professor_id': professorId,
          'collection': collection?.toJson(),
        }
      : {
          'success': false,
          'retry_requires_new_nfc_scan': retryRequiresNewNfcScan,
        };

  @override
  String toString() => 'CaptureResult(success=$success, $collection)';
}
