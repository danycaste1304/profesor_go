import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/qr/pending_qr.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const code = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PendingQr.take();
  });

  test('accepts only a 43-character QR in an HTTPS URL', () {
    expect(PendingQr.parse('https://example.org/jugar/#qr=$code'), code);
    expect(PendingQr.parse('http://example.org/jugar/#qr=$code'), isNull);
    expect(PendingQr.parse('https://example.org/jugar/#qr=short'), isNull);
    expect(PendingQr.parse('https://example.org/jugar/?qr=$code'), isNull);
    expect(PendingQr.parse(code), isNull);
  });

  test(
    'persists across OAuth-style restart and consumes exactly once',
    () async {
      await PendingQr.save(code);
      await PendingQr.initialize();
      expect(PendingQr.hasCode, isTrue);
      expect(await PendingQr.take(), code);
      expect(await PendingQr.take(), isNull);
      await PendingQr.initialize();
      expect(PendingQr.hasCode, isFalse);
    },
  );
}
