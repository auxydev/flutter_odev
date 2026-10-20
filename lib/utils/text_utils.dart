/// Türkçe'ye duyarlı metin yardımcıları.
///
/// Dart'ın `toUpperCase` / `toLowerCase` fonksiyonları I/ı ve İ/i
/// dönüşümlerini Türkçe kurallarına göre yapmaz, bu yüzden elle ele alıyoruz.
library;

String trUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

String trLower(String s) =>
    s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

/// "SÜT 1L" -> "Süt 1L", "İÇECEK" -> "İçecek", "MİGROS A.Ş." -> "Migros A.Ş."
String trTitleCase(String s) {
  final abbreviation = RegExp(r'^(\p{L}\.)+\p{L}?\.?$', unicode: true);
  return s
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) {
        if (abbreviation.hasMatch(w) || RegExp(r'\d').hasMatch(w)) return trUpper(w);
        return trUpper(w.substring(0, 1)) + trLower(w.substring(1));
      })
      .join(' ');
}

/// Anahtar kelime eşleştirmesi için metni ASCII büyük harfe çevirir.
/// "Şok Market" -> "SOK MARKET"
String normalizeKey(String s) {
  const map = {
    'ç': 'c', 'Ç': 'C', 'ğ': 'g', 'Ğ': 'G', 'ı': 'i', 'I': 'I', 'İ': 'I',
    'ö': 'o', 'Ö': 'O', 'ş': 's', 'Ş': 'S', 'ü': 'u', 'Ü': 'U',
  };
  final buffer = StringBuffer();
  for (final ch in s.split('')) {
    buffer.write(map[ch] ?? ch);
  }
  return buffer.toString().toUpperCase();
}
