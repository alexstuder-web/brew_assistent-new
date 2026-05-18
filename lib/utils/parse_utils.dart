/// Parst einen Dezimalwert aus einem Eingabefeld.
///
/// Akzeptiert sowohl Punkt als auch Komma als Dezimaltrenner.
/// Gibt `null` zurück, wenn der String leer oder ungültig ist.
double? tryParseDouble(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned.replaceAll(',', '.'));
}
