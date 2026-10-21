import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:profesor_go/core/nfc/real_nfc_service.dart';

NdefRecord _textRecord(String text, {String lang = 'en'}) => NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x54]),
      identifier: Uint8List(0),
      payload: Uint8List.fromList([
        lang.length,
        ...utf8.encode(lang),
        ...utf8.encode(text),
      ]),
    );

void main() {
  group('RealNfcService helpers', () {
    test('bytesToHex is upper-case and zero padded', () {
      expect(RealNfcService.bytesToHex(Uint8List.fromList([0x04, 0xa3, 0x0f, 0xff])), '04A30FFF');
    });

    test('textFromNdef reads the well-known text record', () {
      final msg = NdefMessage(records: [_textRecord('DEMO-TAG-03')]);
      expect(RealNfcService.textFromNdef(msg), 'DEMO-TAG-03');
    });

    test('textFromNdef reads text/plain media records and skips others', () {
      final uri = NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList([0x55]),
        identifier: Uint8List(0),
        payload: Uint8List.fromList([0x01, ...utf8.encode('example.com')]),
      );
      final plain = NdefRecord(
        typeNameFormat: TypeNameFormat.media,
        type: Uint8List.fromList(utf8.encode('text/plain')),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(utf8.encode(' DEMO-TAG-07 ')),
      );
      expect(RealNfcService.textFromNdef(NdefMessage(records: [uri, plain])), 'DEMO-TAG-07');
      expect(RealNfcService.textFromNdef(NdefMessage(records: [uri])), isNull);
      expect(RealNfcService.textFromNdef(null), isNull);
    });
  });
}
