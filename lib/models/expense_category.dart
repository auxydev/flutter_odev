import 'package:flutter/material.dart';

import '../utils/text_utils.dart';

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.keywords = const [],
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;

  /// Mağaza adı / fiş metninde aranan anahtar kelimeler (ASCII büyük harf).
  final List<String> keywords;

  static const fallbackId = 'diger';

  static const all = <ExpenseCategory>[
    ExpenseCategory(
      id: 'market',
      label: 'Market',
      icon: Icons.shopping_cart_outlined,
      color: Color(0xFF16A34A),
      keywords: [
        'MIGROS', 'BIM', 'A101', 'SOK', 'CARREFOUR', 'CARREFOURSA', 'METRO GROSMARKET',
        'MARKET', 'MARKETLERI', 'GROSS', 'HAPPY CENTER', 'FILE', 'TARIM KREDI', 'MACROCENTER',
        'MANAV', 'KASAP', 'BAKKAL', 'ONUR', 'HAKMAR',
      ],
    ),
    ExpenseCategory(
      id: 'yeme',
      label: 'Yeme & İçme',
      icon: Icons.restaurant_outlined,
      color: Color(0xFFEA580C),
      keywords: [
        'RESTORAN', 'RESTAURANT', 'LOKANTA', 'LOKANTASI', 'CAFE', 'KAFE', 'KAHVE', 'COFFEE',
        'STARBUCKS', 'BURGER', 'PIZZA', 'DONER', 'KEBAP', 'PASTANE', 'PASTANESI', 'FIRIN',
        'FIRINI', 'SIMIT', 'BAKLAVA', 'BISTRO', 'MAYDONOZ',
      ],
    ),
    ExpenseCategory(
      id: 'akaryakit',
      label: 'Akaryakıt',
      icon: Icons.local_gas_station_outlined,
      color: Color(0xFF2563EB),
      keywords: [
        'OPET', 'SHELL', 'PETROL', 'PETROL OFISI', 'BP', 'TOTALENERGIES', 'AYTEMIZ',
        'AKARYAKIT', 'MOTORIN', 'BENZIN', 'LPG', 'KURSUNSUZ',
      ],
    ),
    ExpenseCategory(
      id: 'saglik',
      label: 'Sağlık',
      icon: Icons.local_pharmacy_outlined,
      color: Color(0xFFDC2626),
      keywords: ['ECZANE', 'ECZANESI', 'ECZA', 'HASTANE', 'HASTANESI', 'KLINIK', 'SAGLIK', 'OPTIK'],
    ),
    ExpenseCategory(
      id: 'giyim',
      label: 'Giyim',
      icon: Icons.checkroom_outlined,
      color: Color(0xFF9333EA),
      keywords: [
        'LC WAIKIKI', 'LCW', 'DEFACTO', 'KOTON', 'ZARA', 'H&M', 'MAVI', 'BOYNER', 'FLO',
        'TEKSTIL', 'GIYIM', 'AYAKKABI', 'COLINS',
      ],
    ),
    ExpenseCategory(
      id: 'elektronik',
      label: 'Elektronik',
      icon: Icons.devices_other_outlined,
      color: Color(0xFF0891B2),
      keywords: ['TEKNOSA', 'MEDIAMARKT', 'MEDIA MARKT', 'VATAN', 'ELEKTRONIK', 'BILGISAYAR'],
    ),
    ExpenseCategory(
      id: 'fatura',
      label: 'Fatura & Abonelik',
      icon: Icons.receipt_outlined,
      color: Color(0xFFCA8A04),
      keywords: [
        'ELEKTRIK', 'DOGALGAZ', 'IGDAS', 'SU IDARESI', 'ISKI', 'TURKCELL', 'VODAFONE',
        'TURK TELEKOM', 'INTERNET', 'FATURA',
      ],
    ),
    ExpenseCategory(
      id: 'ulasim',
      label: 'Ulaşım',
      icon: Icons.directions_bus_outlined,
      color: Color(0xFF4F46E5),
      keywords: ['TAKSI', 'OTOPARK', 'ISTANBULKART', 'TURIZM', 'OTOBUS', 'HGS', 'OGS', 'OTOGAR'],
    ),
    ExpenseCategory(
      id: fallbackId,
      label: 'Diğer',
      icon: Icons.category_outlined,
      color: Color(0xFF64748B),
    ),
  ];

  static ExpenseCategory byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => all.last);

  /// Önce mağaza adına, bulunamazsa tüm fiş metnine bakarak kategori tahmin eder.
  static String guess(String? storeName, String fullText) {
    for (final source in [storeName ?? '', fullText]) {
      final text = normalizeKey(source);
      if (text.isEmpty) continue;
      for (final category in all) {
        for (final keyword in category.keywords) {
          final pattern = RegExp('(^|[^A-Z0-9])${RegExp.escape(keyword)}(\$|[^A-Z0-9])');
          if (pattern.hasMatch(text)) return category.id;
        }
      }
    }
    return fallbackId;
  }
}
