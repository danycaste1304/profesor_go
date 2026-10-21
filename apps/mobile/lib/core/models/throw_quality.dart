/// Quality of the throw in the capture mini-game (CONTRACTS §1/§2).
/// The bonus values mirror the `throw_bonus` row in `app_settings`.
enum ThrowQuality {
  miss('MISS', 'Fallo', -1.0),
  good('GOOD', 'Bien', 0.0),
  great('GREAT', 'Genial', 0.10),
  excellent('EXCELLENT', 'Excelente', 0.20);

  const ThrowQuality(this.wireValue, this.label, this.bonus);

  final String wireValue;

  /// User-facing label (Spanish).
  final String label;

  /// Added to the professor base rate; MISS forces p = 0.
  final double bonus;

  static ThrowQuality parse(String value) {
    final q = tryParse(value);
    if (q == null) throw FormatException('Unknown throw quality: $value');
    return q;
  }

  static ThrowQuality? tryParse(String? value) {
    if (value == null) return null;
    final v = value.trim().toUpperCase();
    for (final q in values) {
      if (q.wireValue == v) return q;
    }
    return null;
  }
}
