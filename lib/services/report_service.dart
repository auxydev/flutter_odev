import '../models/receipt.dart';
import '../utils/format.dart';
import '../utils/text_utils.dart';

enum ReportPeriod {
  daily('Günlük'),
  weekly('Haftalık'),
  monthly('Aylık');

  const ReportPeriod(this.label);
  final String label;
}

class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;

  /// Hariç (exclusive).
  final DateTime end;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
}

DateRange rangeFor(ReportPeriod period, DateTime anchor) {
  switch (period) {
    case ReportPeriod.daily:
      final start = DateTime(anchor.year, anchor.month, anchor.day);
      return DateRange(start, DateTime(start.year, start.month, start.day + 1));
    case ReportPeriod.weekly:
      // Hafta pazartesi başlar.
      final start = DateTime(anchor.year, anchor.month, anchor.day - (anchor.weekday - 1));
      return DateRange(start, DateTime(start.year, start.month, start.day + 7));
    case ReportPeriod.monthly:
      return DateRange(
        DateTime(anchor.year, anchor.month),
        DateTime(anchor.year, anchor.month + 1),
      );
  }
}

DateTime shiftAnchor(ReportPeriod period, DateTime anchor, int delta) => switch (period) {
      ReportPeriod.daily => DateTime(anchor.year, anchor.month, anchor.day + delta),
      ReportPeriod.weekly => DateTime(anchor.year, anchor.month, anchor.day + 7 * delta),
      ReportPeriod.monthly => DateTime(anchor.year, anchor.month + delta),
    };

String rangeLabel(ReportPeriod period, DateRange range) {
  switch (period) {
    case ReportPeriod.daily:
      return '${formatDate(range.start)}, ${formatWeekday(range.start)}';
    case ReportPeriod.weekly:
      final last = range.end.subtract(const Duration(days: 1));
      final sameMonth = last.month == range.start.month;
      final startText = sameMonth ? '${range.start.day}' : formatDateShort(range.start);
      return '$startText – ${formatDateShort(last)}';
    case ReportPeriod.monthly:
      return formatMonthYear(range.start);
  }
}

class ChartBucket {
  const ChartBucket(this.label, this.tooltip, this.value);
  final String label;
  final String tooltip;
  final double value;
}

class ItemSummary {
  ItemSummary(this.name);
  final String name;
  double quantity = 0;
  double total = 0;
  int receiptCount = 0;
}

class AmountShare {
  const AmountShare(this.key, this.amount, this.count);
  final String key;
  final double amount;
  final int count;
}

class ReportData {
  ReportData._({
    required this.receipts,
    required this.total,
    required this.vat,
    required this.byCategory,
    required this.byStore,
    required this.items,
    required this.buckets,
  });

  final List<Receipt> receipts;
  final double total;
  final double vat;
  final List<AmountShare> byCategory;
  final List<AmountShare> byStore;
  final List<ItemSummary> items;
  final List<ChartBucket> buckets;

  int get count => receipts.length;
  double get average => count == 0 ? 0 : total / count;

  static const _weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  factory ReportData.build(List<Receipt> all, DateRange range, ReportPeriod period) {
    final receipts = all.where((r) => range.contains(r.date)).toList();

    var total = 0.0, vat = 0.0;
    final categoryTotals = <String, (double, int)>{};
    final storeTotals = <String, (double, int)>{};
    final items = <String, ItemSummary>{};

    for (final r in receipts) {
      total += r.total;
      vat += r.vat ?? 0;
      final c = categoryTotals[r.category] ?? (0, 0);
      categoryTotals[r.category] = (c.$1 + r.total, c.$2 + 1);
      final s = storeTotals[r.storeName] ?? (0, 0);
      storeTotals[r.storeName] = (s.$1 + r.total, s.$2 + 1);

      for (final item in r.items) {
        final key = normalizeKey(item.name).replaceAll(RegExp(r'\s+'), ' ');
        final summary = items.putIfAbsent(key, () => ItemSummary(item.name));
        summary.quantity += item.quantity;
        summary.total += item.total;
        summary.receiptCount++;
      }
    }

    List<AmountShare> sorted(Map<String, (double, int)> m) =>
        m.entries.map((e) => AmountShare(e.key, e.value.$1, e.value.$2)).toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    return ReportData._(
      receipts: receipts,
      total: total,
      vat: vat,
      byCategory: sorted(categoryTotals),
      byStore: sorted(storeTotals),
      items: items.values.toList()..sort((a, b) => b.total.compareTo(a.total)),
      buckets: _buckets(receipts, range, period),
    );
  }

  static List<ChartBucket> _buckets(List<Receipt> receipts, DateRange range, ReportPeriod period) {
    switch (period) {
      case ReportPeriod.daily:
        // 3 saatlik dilimler: 00-03, 03-06, ...
        final values = List<double>.filled(8, 0);
        for (final r in receipts) {
          values[r.date.hour ~/ 3] += r.total;
        }
        return [
          for (var i = 0; i < 8; i++)
            ChartBucket(
              (i * 3).toString().padLeft(2, '0'),
              '${(i * 3).toString().padLeft(2, '0')}:00 – ${(i * 3 + 3).toString().padLeft(2, '0')}:00',
              values[i],
            ),
        ];
      case ReportPeriod.weekly:
        final values = List<double>.filled(7, 0);
        for (final r in receipts) {
          values[r.date.weekday - 1] += r.total;
        }
        return [
          for (var i = 0; i < 7; i++)
            ChartBucket(
              _weekdays[i],
              formatDateShort(DateTime(range.start.year, range.start.month, range.start.day + i)),
              values[i],
            ),
        ];
      case ReportPeriod.monthly:
        final dayCount = DateTime(range.start.year, range.start.month + 1, 0).day;
        final values = List<double>.filled(dayCount, 0);
        for (final r in receipts) {
          values[r.date.day - 1] += r.total;
        }
        return [
          for (var i = 0; i < dayCount; i++)
            ChartBucket(
              (i == 0 || (i + 1) % 5 == 0) ? '${i + 1}' : '',
              formatDateShort(DateTime(range.start.year, range.start.month, i + 1)),
              values[i],
            ),
        ];
    }
  }
}
