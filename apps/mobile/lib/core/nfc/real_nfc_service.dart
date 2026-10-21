import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart' as nm;
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import '../errors/app_exception.dart';
import 'nfc_service.dart';

/// [NfcService] backed by `nfc_manager`.
///
/// Reads the first NDEF text record (`T` well-known type or `text/plain`) if
/// present, otherwise falls back to the tag UID in upper-case hex.
class RealNfcService implements NfcService {
  RealNfcService({
    nm.NfcManager? manager,
    this.timeout = const Duration(seconds: 60),
  }) : _managerOverride = manager;

  final nm.NfcManager? _managerOverride;
  final Duration timeout;

  Completer<String?>? _pending;
  Timer? _timer;

  nm.NfcManager get _manager => _managerOverride ?? nm.NfcManager.instance;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<NfcAvailability> availability() async {
    if (!_isAndroid && !_isIos) return NfcAvailability.unsupported;
    try {
      return switch (await _manager.checkAvailability()) {
        nm.NfcAvailability.enabled => NfcAvailability.available,
        nm.NfcAvailability.disabled => NfcAvailability.disabled,
        nm.NfcAvailability.unsupported => NfcAvailability.unsupported,
      };
    } catch (_) {
      return NfcAvailability.unsupported;
    }
  }

  @override
  Future<String?> scanTag() async {
    // Only one session at a time: cancel a previous pending scan.
    if (_pending != null) await cancel();

    switch (await availability()) {
      case NfcAvailability.unsupported:
        throw AppException.fromCode(AppException.nfcUnsupported);
      case NfcAvailability.disabled:
        throw AppException.fromCode(AppException.nfcDisabled);
      case NfcAvailability.available:
        break;
    }

    final completer = Completer<String?>();
    _pending = completer;
    _timer = Timer(timeout, () => unawaited(_stopAndFinish(null)));

    try {
      await _manager.startSession(
        pollingOptions: {
          nm.NfcPollingOption.iso14443,
          nm.NfcPollingOption.iso15693,
          nm.NfcPollingOption.iso18092,
        },
        alertMessageIos: 'Acerca el móvil a la tarjeta del profesor',
        onSessionErrorIos: (error) {
          if (error.code ==
                  NfcReaderErrorCodeIos
                      .readerSessionInvalidationErrorUserCanceled ||
              error.code ==
                  NfcReaderErrorCodeIos
                      .readerSessionInvalidationErrorSessionTimeout) {
            _finish(null);
          } else if (error.code ==
              NfcReaderErrorCodeIos
                  .readerSessionInvalidationErrorFirstNDEFTagRead) {
            // Normal invalidation after the first read; onDiscovered handles it.
          } else {
            _fail(AppException.fromCode(AppException.nfcReadError, cause: error));
          }
        },
        onDiscovered: (tag) async {
          String? identifier;
          Object? error;
          try {
            identifier = await _extractIdentifier(tag);
          } catch (e) {
            error = e;
          }
          await _safeStop(
            alertMessageIos: identifier != null ? 'Tarjeta leída' : null,
            errorMessageIos:
                identifier == null ? 'No se pudo leer la tarjeta' : null,
          );
          if (identifier != null) {
            _finish(identifier);
          } else {
            _fail(
              AppException.fromCode(AppException.nfcReadError, cause: error),
            );
          }
        },
      );
    } catch (e) {
      _fail(AppException.fromCode(AppException.nfcReadError, cause: e));
    }
    return completer.future;
  }

  @override
  Future<void> cancel() async {
    if (_pending == null) return;
    await _stopAndFinish(null);
  }

  Future<void> _stopAndFinish(String? value) async {
    await _safeStop();
    _finish(value);
  }

  Future<void> _safeStop({String? alertMessageIos, String? errorMessageIos}) {
    return _manager
        .stopSession(
          alertMessageIos: alertMessageIos,
          errorMessageIos: errorMessageIos,
        )
        .catchError((Object _) {});
  }

  void _finish(String? value) {
    _timer?.cancel();
    _timer = null;
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.complete(value);
  }

  void _fail(AppException error) {
    _timer?.cancel();
    _timer = null;
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.completeError(error);
  }

  Future<String?> _extractIdentifier(nm.NfcTag tag) async {
    if (_isAndroid) return _extractAndroid(tag);
    if (_isIos) return _extractIos(tag);
    return null;
  }

  Future<String?> _extractAndroid(nm.NfcTag tag) async {
    final ndef = NdefAndroid.from(tag);
    if (ndef != null) {
      var text = textFromNdef(ndef.cachedNdefMessage);
      if (text == null) {
        try {
          text = textFromNdef(await ndef.getNdefMessage());
        } catch (_) {
          // Fall through to the UID.
        }
      }
      if (text != null) return text;
    }
    final raw = NfcTagAndroid.from(tag);
    return raw == null || raw.id.isEmpty ? null : bytesToHex(raw.id);
  }

  Future<String?> _extractIos(nm.NfcTag tag) async {
    final ndef = NdefIos.from(tag);
    if (ndef != null) {
      var text = textFromNdef(ndef.cachedNdefMessage);
      if (text == null && ndef.status != NdefStatusIos.notSupported) {
        try {
          text = textFromNdef(await ndef.readNdef());
        } catch (_) {
          // Fall through to the UID.
        }
      }
      if (text != null) return text;
    }
    final mifare = MiFareIos.from(tag);
    if (mifare != null) return bytesToHex(mifare.identifier);
    final iso15693 = Iso15693Ios.from(tag);
    if (iso15693 != null) return bytesToHex(iso15693.identifier);
    final iso7816 = Iso7816Ios.from(tag);
    if (iso7816 != null) return bytesToHex(iso7816.identifier);
    final felica = FeliCaIos.from(tag);
    if (felica != null) return bytesToHex(felica.currentIDm);
    return null;
  }

  /// Returns the first text payload of an NDEF message, or null.
  /// Supports the well-known `T` record (RFC 3066 language prefix) and
  /// `text/plain` media records.
  @visibleForTesting
  static String? textFromNdef(NdefMessage? message) {
    if (message == null) return null;
    for (final record in message.records) {
      final text = _textFromRecord(record);
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  static String? _textFromRecord(NdefRecord record) {
    try {
      switch (record.typeNameFormat) {
        case TypeNameFormat.wellKnown:
          if (record.type.length == 1 && record.type[0] == 0x54) {
            final payload = record.payload;
            if (payload.isEmpty) return null;
            final status = payload[0];
            final langLength = status & 0x3F;
            final isUtf16 = (status & 0x80) != 0;
            if (payload.length <= 1 + langLength) return null;
            final bytes = payload.sublist(1 + langLength);
            return (isUtf16 ? _decodeUtf16(bytes) : utf8.decode(bytes)).trim();
          }
          return null;
        case TypeNameFormat.media:
          if (utf8.decode(record.type, allowMalformed: true) == 'text/plain') {
            return utf8.decode(record.payload, allowMalformed: true).trim();
          }
          return null;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  static String _decodeUtf16(Uint8List bytes) {
    // Big-endian by default; honour a BOM if present.
    var offset = 0;
    var littleEndian = false;
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        littleEndian = true;
        offset = 2;
      } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        offset = 2;
      }
    }
    final units = <int>[];
    for (var i = offset; i + 1 < bytes.length; i += 2) {
      units.add(
        littleEndian ? bytes[i] | (bytes[i + 1] << 8) : (bytes[i] << 8) | bytes[i + 1],
      );
    }
    return String.fromCharCodes(units);
  }

  @visibleForTesting
  static String bytesToHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
}
