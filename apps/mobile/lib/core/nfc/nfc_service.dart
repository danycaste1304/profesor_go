/// NFC availability on this device.
enum NfcAvailability { available, disabled, unsupported }

/// Reads the identifier of a professor card.
///
/// The identifier is the NDEF text record when present (e.g. `DEMO-TAG-01`),
/// otherwise the tag UID as upper-case hex. Errors are thrown as
/// `AppException`; `null` means the scan was cancelled or timed out.
abstract class NfcService {
  /// Starts a session and resolves with the tag identifier of the first tag
  /// discovered, or `null` if cancelled / timed out.
  Future<String?> scanTag();

  Future<NfcAvailability> availability();

  /// Stops the current session (if any); a pending [scanTag] resolves `null`.
  Future<void> cancel();
}
