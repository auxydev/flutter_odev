import '../models/expense_category.dart';
import '../models/receipt.dart';
import '../utils/text_utils.dart';

/// Fiş metninden çıkarılan ham bilgiler. Kullanıcı kaydetmeden önce düzenler.
class ParsedReceipt {
  ParsedReceipt({
    this.storeName,
    this.date,
    this.items = const [],
    this.total,
    this.vat,
    this.paymentMethod,
    this.receiptNo,
    required this.category,
    required this.rawText,
  });

  final String? storeName;
  final DateTime? date;
  final List<ReceiptItem> items;
  final double? total;
  final double? vat;
  final String? paymentMethod;
  final String? receiptNo;
  final String category;
  final String rawText;

  double get itemsTotal => items.fold(0, (sum, i) => sum + i.total);
}

/// Türkiye'deki yazar kasa / ÖKC fişlerinin tipik düzenine göre çalışan ayrıştırıcı.
///
/// Örnek bir fiş:
/// ```
/// MİGROS TİCARET A.Ş.
/// TARİH: 15.10.2026   SAAT: 14:32
/// FİŞ NO: 0045
/// 2 AD X 12,50
/// EKMEK              %01  *25,00
/// SÜT 1L             %01  *32,90
/// TOPKDV                  *0,58
/// TOPLAM                  *57,90
/// NAKİT                   *60,00
/// ```
class ReceiptParser {
  const ReceiptParser();

  /// Satır sonundaki tutar: "*12,50", "1.234,56", "65.40 TL", "-5,00"
  /// ML Kit bazen son haneyi düşürdüğü için "*" ile başlayan "*24,9" da kabul edilir.
  static final _amountAtEnd = RegExp(
    r'[*#]?\s*(-?\s?\d{1,3}(?:\.\d{3})+,\d{2}|-?\s?\d+[.,]\d{2}|(?<=\*\s?)\d+[.,]\d)\s*(?:TL|₺)?\s*$',
    caseSensitive: false,
  );

  /// "2 AD X 12,50", "0,750 KG X 45,00", "3 x 4.25"
  static final _quantityLine = RegExp(
    r'^(\d+(?:[.,]\d+)?)\s*(?:AD(?:ET)?|AD\.|KG|GR|LT|L|PK|ADT)?\s*[Xx*]\s*\*?(\d+[.,]\d{2})\s*$',
    caseSensitive: false,
  );

  static final _date = RegExp(r'(\d{1,2})\s?[./-]\s?(\d{1,2})\s?[./-]\s?(\d{4}|\d{2})(?!\d)');
  static final _time = RegExp(r'(?<!\d)([01]?\d|2[0-3])\s?:\s?([0-5]\d)(?::[0-5]\d)?(?!\d)');
  static final _receiptNo = RegExp(r'FIS\s*NO\s*[:.]?\s*(\d+)');
  static final _vatMarker = RegExp(r'%\s*\d{1,2}');

  /// Ürün olmayan ama tutar içerebilen satırlar (tam kelime olarak aranır).
  static const _nonItemKeywords = [
    'TOPLAM', 'TOPLAMI', 'TOPKDV', 'KDV', 'NAKIT', 'KREDI', 'KART', 'KARTI', 'PARA USTU',
    'ODENEN', 'ODENECEK', 'BAKIYE', 'PUAN', 'ALINAN', 'VISA', 'MASTER', 'MASTERCARD', 'BANKA',
    'BANKASI', 'PROVIZYON', 'ONAY', 'TERMINAL', 'SAAT', 'TARIH', 'FIS', 'Z NO', 'EKU', 'MERSIS',
    'VKN', 'TCKN', 'VD', 'V.D', 'VERGI', 'TEL', 'ADRES', 'KASIYER', 'ISLEM', 'TUTAR', 'TUTARI',
    'MATRAH', 'MATRAHI', 'BRUT', 'NET', 'CEK', 'YUVARLAMA', 'TESEKKUR', 'TESEKKURLER', 'MALI',
    'BELGE', 'REF', 'BATCH', 'STAN', 'AID',
  ];

  static const _storeSkipKeywords = [
    'HOSGELDINIZ', 'HOS GELDINIZ', 'TARIH', 'SAAT', 'FIS', 'TEL', 'VD', 'V.D', 'VERGI',
    'MERSIS', 'VKN', 'TCKN', 'NO', 'MAH', 'MAHALLESI', 'CAD', 'CADDESI', 'CD', 'SOKAK',
    'SOKAGI', 'SK', 'ADRES', 'BULVARI', 'BLV',
  ];

  ParsedReceipt parse(String text) {
    final rawLines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.replaceAll('\t', ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final lines = rawLines.map(_cleanOcrLine).toList();
    final keys = lines.map(normalizeKey).toList();

    final storeName = _findStoreName(lines, keys);
    final date = _findDate(lines, keys);
    final totalInfo = _findTotal(lines, keys);
    final vat = _findVat(lines, keys);
    final items = _findItems(lines, keys, totalInfo?.index ?? lines.length);

    return ParsedReceipt(
      storeName: storeName,
      date: date,
      items: items,
      total: totalInfo?.amount ?? (items.isEmpty ? null : _round(items.fold(0.0, (s, i) => s + i.total))),
      vat: vat,
      paymentMethod: _findPayment(keys),
      receiptNo: _findReceiptNo(keys),
      category: ExpenseCategory.guess(storeName, lines.join('\n')),
      rawText: rawLines.join('\n'),
    );
  }

  // ---------------------------------------------------------------------------

  /// OCR'ın Türkçe harfler yerine okuduğu benzer görünümlü harfler.
  /// Örn. "İ" sıkça "Í", "Ỉ" (U+1EC8) ya da "I" + birleşik nokta olarak gelir.
  static const _lookalikes = {
    'İ': 'ÍÌÎÏĪĬĮỈỊ', 'i': 'íìîïīĭįỉị',
    'Ö': 'ÒÓÔÕŌŐỎỌ', 'ö': 'òóôõōőỏọ',
    'Ü': 'ÙÚÛŨŪŰỦỤ', 'ü': 'ùúûũūűủụ',
    'Ş': 'ŚȘŠ', 'ş': 'śșš',
    'Ç': 'ĆČ', 'ç': 'ćč',
    'Ğ': 'Ǧ', 'ğ': 'ǧ',
  };

  /// ML Kit'in fişlerde sık yaptığı karakter karışıklıklarını düzeltir.
  static String _cleanOcrLine(String line) {
    var s = line
        .replaceAll('İ', 'İ')
        .replaceAll('i̇', 'i')
        .replaceAll(RegExp('[̀-ͯ]'), '');
    for (final entry in _lookalikes.entries) {
      s = s.replaceAll(RegExp('[${entry.value}]'), entry.key);
    }

    // Sayıların içindeki O harfi aslında sıfırdır: "*624,O5", "%O1", "O.5L", "1OO,00"
    // ("NO.0045" gibi harften sonra gelen O'lara dokunulmaz.)
    final letterO = RegExp(r'(?<=\d[.,]?|[*%])[Oo]|(?<![A-Za-zÇĞİÖŞÜçğıöşü])[Oo](?=[.,]?\d)');
    for (var i = 0; i < 3 && letterO.hasMatch(s); i++) {
      s = s.replaceAll(letterO, '0');
    }

    // Ayırıcıdan sonra gelen boşluk: "*37, 50" -> "*37,50"
    return s.replaceAllMapped(
      RegExp(r'(\d)([.,]) (\d{2})(?!\d)'),
      (m) => '${m[1]}${m[2]}${m[3]}',
    );
  }

  static double? amountOf(String line) {
    final m = _amountAtEnd.firstMatch(line);
    if (m == null) return null;
    return _parseAmount(m.group(1)!);
  }

  /// "1.234,56" -> 1234.56, "*24,9" -> 24.90, "-5,00" -> -5.0
  static double _parseAmount(String raw) {
    final s = raw.replaceAll(RegExp(r'\s'), '');
    final separator = s.lastIndexOf(RegExp(r'[.,]'));
    final whole = s.substring(0, separator).replaceAll(RegExp(r'\D'), '');
    final fraction = s.substring(separator + 1).padRight(2, '0');
    final value = int.parse('$whole$fraction') / 100;
    return s.startsWith('-') ? -value : value;
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  static bool _hasLetters(String s, [int min = 2]) =>
      RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').allMatches(s).length >= min;

  static bool _containsAny(String key, List<String> keywords) => keywords.any(
      (k) => RegExp('(^|[^A-Z0-9])${RegExp.escape(k)}(\$|[^A-Z0-9])').hasMatch(key));

  String? _findStoreName(List<String> lines, List<String> keys) {
    for (var i = 0; i < lines.length && i < 6; i++) {
      final line = lines[i];
      if (!_hasLetters(line, 3)) continue;
      if (_containsAny(keys[i], _storeSkipKeywords)) continue;
      if (_date.hasMatch(line) || amountOf(line) != null) continue;
      final cleaned = line.replaceAll(RegExp(r'[*#=_]+'), ' ').trim();
      return trTitleCase(cleaned);
    }
    return null;
  }

  DateTime? _findDate(List<String> lines, List<String> keys) {
    for (var i = 0; i < lines.length; i++) {
      for (final m in _date.allMatches(lines[i])) {
        final day = int.parse(m.group(1)!);
        final month = int.parse(m.group(2)!);
        var year = int.parse(m.group(3)!);
        if (year < 100) year += 2000;
        if (day < 1 || day > 31 || month < 1 || month > 12 || year < 2000 || year > 2100) {
          continue;
        }
        // Saat genelde aynı satırda ya da "SAAT" içeren satırda olur.
        var hour = 12, minute = 0;
        final sameLine = lines[i].replaceRange(m.start, m.end, ' ');
        final timeLine = _time.hasMatch(sameLine)
            ? sameLine
            : lines.firstWhere(
                (l) => normalizeKey(l).contains('SAAT') && _time.hasMatch(l),
                orElse: () => '',
              );
        final t = _time.firstMatch(timeLine);
        if (t != null) {
          hour = int.parse(t.group(1)!);
          minute = int.parse(t.group(2)!);
        }
        return DateTime(year, month, day, hour, minute);
      }
    }
    return null;
  }

  ({int index, double amount})? _findTotal(List<String> lines, List<String> keys) {
    ({int index, double amount})? best;
    var bestIsGeneral = false;
    for (var i = 0; i < lines.length; i++) {
      final key = keys[i];
      final isTotal = (key.contains('TOPLAM') || key.contains('ODENECEK')) &&
          !key.contains('KDV') &&
          !key.contains('ARA') &&
          !key.contains('INDIRIM');
      if (!isTotal) continue;

      var amount = amountOf(lines[i]);
      // Tutar bazen bir sonraki satıra düşer.
      if (amount == null && i + 1 < lines.length && !_hasLetters(lines[i + 1], 1)) {
        amount = amountOf(lines[i + 1]);
      }
      if (amount == null || amount <= 0) continue;

      final isGeneral = key.contains('GENEL');
      if (best == null ||
          (isGeneral && !bestIsGeneral) ||
          (isGeneral == bestIsGeneral && amount > best.amount)) {
        best = (index: i, amount: amount);
        bestIsGeneral = isGeneral;
      }
    }
    return best;
  }

  double? _findVat(List<String> lines, List<String> keys) {
    for (var i = 0; i < lines.length; i++) {
      final key = keys[i].replaceAll(' ', '');
      if (key.contains('TOPKDV') || (key.contains('KDV') && key.contains('TOPLAM'))) {
        final amount = amountOf(lines[i]) ??
            (i + 1 < lines.length && !_hasLetters(lines[i + 1], 1) ? amountOf(lines[i + 1]) : null);
        if (amount != null) return amount;
      }
    }
    return null;
  }

  List<ReceiptItem> _findItems(List<String> lines, List<String> keys, int endIndex) {
    final items = <ReceiptItem>[];
    double? pendingQty;
    String? pendingName;

    for (var i = 0; i < endIndex; i++) {
      final line = lines[i];
      final key = keys[i];

      final qty = _quantityLine.firstMatch(line);
      if (qty != null) {
        pendingQty = double.tryParse(qty.group(1)!.replaceAll(',', '.'));
        continue;
      }

      if (_date.hasMatch(line)) {
        pendingName = null;
        continue;
      }

      final amountMatch = _amountAtEnd.firstMatch(line);
      if (amountMatch == null) {
        // Fiyatı alt satıra düşmüş ürün adı olabilir.
        final isCandidate = _hasLetters(line) && !_containsAny(key, _nonItemKeywords);
        pendingName = isCandidate ? line : null;
        continue;
      }

      final amount = _parseAmount(amountMatch.group(1)!);
      var name = _cleanName(line.substring(0, amountMatch.start));
      final nameKey = normalizeKey(name);

      if (nameKey.contains('INDIRIM') && amount != 0) {
        items.add(ReceiptItem(name: 'İndirim', total: -amount.abs()));
        pendingQty = null;
        pendingName = null;
        continue;
      }

      if (!_hasLetters(name)) {
        if (pendingName == null) continue;
        name = _cleanName(pendingName);
      } else if (_containsAny(nameKey, _nonItemKeywords)) {
        pendingName = null;
        pendingQty = null;
        continue;
      }

      if (amount <= 0) continue;
      items.add(ReceiptItem(
        name: trTitleCase(name),
        quantity: pendingQty ?? 1,
        total: amount,
      ));
      pendingQty = null;
      pendingName = null;
    }
    return items;
  }

  String _cleanName(String raw) => raw
      .replaceAll(_vatMarker, ' ')
      .replaceAll(RegExp(r'[*#]+'), ' ')
      .replaceAll(RegExp(r'^\d{8,14}\s+'), '') // baştaki barkod
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String? _findPayment(List<String> keys) {
    final all = keys.join(' ');
    if (RegExp(r'KREDI|KART|VISA|MASTER|BANKA|TEMASSIZ').hasMatch(all)) return 'Kart';
    if (all.contains('NAKIT')) return 'Nakit';
    return null;
  }

  String? _findReceiptNo(List<String> keys) {
    for (final key in keys) {
      final m = _receiptNo.firstMatch(key);
      if (m != null) return m.group(1);
    }
    return null;
  }
}
