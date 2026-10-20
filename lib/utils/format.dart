import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final _compactMoney = NumberFormat.compactCurrency(locale: 'tr_TR', symbol: '₺');

String formatMoney(double value) => _money.format(value);

String formatMoneyCompact(double value) =>
    value.abs() < 10000 ? formatMoney(value) : _compactMoney.format(value);

String formatDate(DateTime d) => DateFormat('d MMMM y', 'tr_TR').format(d);

String formatDateShort(DateTime d) => DateFormat('d MMM y', 'tr_TR').format(d);

String formatDateTime(DateTime d) => DateFormat('d MMMM y, HH:mm', 'tr_TR').format(d);

String formatWeekday(DateTime d) => DateFormat('EEEE', 'tr_TR').format(d);

String formatMonthYear(DateTime d) => DateFormat('MMMM y', 'tr_TR').format(d);

/// 2 -> "2", 0.75 -> "0,75"
String formatQty(double q) {
  if (q == q.roundToDouble()) return q.toInt().toString();
  return q
      .toStringAsFixed(3)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll('.', ',');
}

/// Kullanıcının yazdığı "12,50" / "12.50" / "1.250,00" gibi değerleri okur.
double? parseUserNumber(String input) {
  var s = input.trim().replaceAll(' ', '').replaceAll('₺', '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(s);
}

/// Düzenleme alanlarında gösterilecek sayı: 12.5 -> "12,50"
String toInputNumber(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
