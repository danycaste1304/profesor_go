/// NFC availability on this device.
enum NfcAvailability { available, disabled, unsupported }

/// Reads the identifier of a professor card.
///
/// The identifier is the Estimote beacon ID when its external NDEF record is
/// present (`ESTIMOTE:<hex>`), otherwise NDEF text or the tag UID as upper-case
/// hex. Errors are thrown as
/// `AppException`; `null` means the scan was cancelled or timed out.
abstract class NfcService {
  /// Starts a session and resolves with the tag identifier of the first tag
  /// discovered, or `null` if cancelled / timed out. [onReady] runs only after
  /// Android has enabled reader mode (or the iOS session has started).
  Future<String?> scanTag({void Function()? onReady});

  Future<NfcAvailability> availability();

  /// Stops the current session (if any); a pending [scanTag] resolves `null`.
  Future<void> cancel();
}
