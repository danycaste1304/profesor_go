import 'package:flutter_test/flutter_test.dart';
import 'package:profesor_go/core/models/rarity.dart';
import 'package:profesor_go/core/models/throw_quality.dart';

void main() {
  group('Rarity.parse', () {
    test('parses canonical wire values', () {
      expect(Rarity.parse('COMMON'), Rarity.common);
      expect(Rarity.parse('RARE'), Rarity.rare);
      expect(Rarity.parse('EPIC'), Rarity.epic);
      expect(Rarity.parse('LEGENDARY'), Rarity.legendary);
    });

    test('is tolerant of case and whitespace', () {
      expect(Rarity.parse('common'), Rarity.common);
      expect(Rarity.parse('  Legendary '), Rarity.legendary);
      expect(Rarity.parse('ePiC'), Rarity.epic);
    });

    test('throws FormatException for unknown values', () {
      expect(() => Rarity.parse('MYTHIC'), throwsFormatException);
      expect(() => Rarity.parse(''), throwsFormatException);
    });

    test('tryParse returns null for null / unknown', () {
      expect(Rarity.tryParse(null), isNull);
      expect(Rarity.tryParse('nope'), isNull);
      expect(Rarity.tryParse('rare'), Rarity.rare);
    });

    test('exposes Spanish labels and default rates', () {
      expect(Rarity.common.label, 'Común');
      expect(Rarity.rare.label, 'Rara');
      expect(Rarity.epic.label, 'Épica');
      expect(Rarity.legendary.label, 'Legendaria');
      expect(Rarity.common.defaultCaptureRate, 0.80);
      expect(Rarity.rare.defaultCaptureRate, 0.60);
      expect(Rarity.epic.defaultCaptureRate, 0.40);
      expect(Rarity.legendary.defaultCaptureRate, 0.25);
      expect(Rarity.legendary.rank, greaterThan(Rarity.common.rank));
    });
  });

  group('ThrowQuality', () {
    test('parses tolerant of case and has the contract bonuses', () {
      expect(ThrowQuality.parse('miss'), ThrowQuality.miss);
      expect(ThrowQuality.parse(' EXCELLENT '), ThrowQuality.excellent);
      expect(ThrowQuality.miss.bonus, -1.0);
      expect(ThrowQuality.good.bonus, 0.0);
      expect(ThrowQuality.great.bonus, 0.10);
      expect(ThrowQuality.excellent.bonus, 0.20);
      expect(() => ThrowQuality.parse('PERFECT'), throwsFormatException);
    });
  });
}
