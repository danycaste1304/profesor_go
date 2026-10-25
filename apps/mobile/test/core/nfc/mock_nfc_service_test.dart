import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/errors/app_exception.dart';
import 'package:profesor_go/core/models/featured_professors.dart';
import 'package:profesor_go/core/nfc/mock_nfc_service.dart';
import 'package:profesor_go/core/nfc/nfc_service.dart';

void main() {
  late MockNfcService nfc;

  setUp(() => nfc = MockNfcService(delay: const Duration(milliseconds: 5)));

  test('exposes DEMO-TAG-01..10 with professor labels', () async {
    final tags = await nfc.demoTags();
    expect(tags.map((t) => t.identifier), [
      for (var n = 1; n <= 10; n++) 'DEMO-TAG-${n.toString().padLeft(2, '0')}',
    ]);
    expect(tags.first.label, 'Prof. Henry');
    expect(tags[1].label, 'Prof. Felipe');
    expect(tags[1].professorId, felipeGrijalvaId);
    expect(tags[2].label, 'Prof. José David');
    expect(tags[2].professorId, joseDavidVegaId);
    expect(tags[3].label, 'Prof. Ricardo');
    expect(tags[3].professorId, ricardoFloresId);
    expect(tags[7].label, 'Prof. Erick');
    expect(tags[7].professorId, erickNaunayId);
    expect(tags[8].professorId, diegoMoralesId);
    expect(tags.last.label, 'Prof. Roberto');
    expect(tags.last.professorId, robertoAndradeId);
  });

  test('scanTag returns the selected tag after the delay', () async {
    expect(await nfc.availability(), NfcAvailability.available);
    expect(await nfc.scanTag(), 'DEMO-TAG-01');
    nfc.selectTag('demo-tag-05');
    expect(await nfc.scanTag(), 'DEMO-TAG-05');
    nfc.selectedTag = (await nfc.demoTags())[7];
    expect(await nfc.scanTag(), 'DEMO-TAG-08');
  });

  test(
    'unknown identifiers can be selected to demo the invalid-card flow',
    () async {
      nfc.selectTag('UNKNOWN-1');
      expect(nfc.selectedTag.label, 'Tarjeta desconocida');
      expect(await nfc.scanTag(), 'UNKNOWN-1');
    },
  );

  test('cancel resolves the pending scan with null', () async {
    nfc = MockNfcService(delay: const Duration(seconds: 5));
    final future = nfc.scanTag();
    await nfc.cancel();
    expect(await future, isNull);
  });

  test('disabled / unsupported NFC throws the matching AppException', () async {
    nfc.availabilityOverride = NfcAvailability.disabled;
    await expectLater(
      nfc.scanTag(),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppException.nfcDisabled,
        ),
      ),
    );
    nfc.availabilityOverride = NfcAvailability.unsupported;
    await expectLater(
      nfc.scanTag(),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppException.nfcUnsupported,
        ),
      ),
    );
  });
}
