/// Professor rarity (CONTRACTS §1). Wire values are upper-case.
enum Rarity {
  common('COMMON', 'Común', 0.80, 'rarityCommon'),
  rare('RARE', 'Rara', 0.60, 'rarityRare'),
  epic('EPIC', 'Épica', 0.40, 'rarityEpic'),
  legendary('LEGENDARY', 'Legendaria', 0.25, 'rarityLegendary');

  const Rarity(
    this.wireValue,
    this.label,
    this.defaultCaptureRate,
    this.colorToken,
  );

  /// Value stored in the database / sent over the wire.
  final String wireValue;

  /// User-facing label (Spanish).
  final String label;

  /// Default base capture rate (admins can override per professor).
  final double defaultCaptureRate;

  /// Theme color token name, resolved by `AppTheme.rarityColor`.
  final String colorToken;

  /// Parses a wire value tolerant of case and surrounding whitespace.
  /// Throws [FormatException] for unknown values.
  static Rarity parse(String value) {
    final r = tryParse(value);
    if (r == null) throw FormatException('Unknown rarity: $value');
    return r;
  }

  /// Like [parse] but returns null for null / unknown values.
  static Rarity? tryParse(String? value) {
    if (value == null) return null;
    final v = value.trim().toUpperCase();
    for (final r in values) {
      if (r.wireValue == v) return r;
    }
    return null;
  }

  /// Higher is rarer (common 0 … legendary 3); used for sorting.
  int get rank => index;
}
