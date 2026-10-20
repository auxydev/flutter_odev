import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense_category.dart';
import '../../services/report_service.dart';
import '../../state/receipt_controller.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/pill_tabs.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.daily;
  DateTime _anchor = DateTime.now();
  bool _showAllItems = false;

  void _shift(int delta) => setState(() {
        _anchor = shiftAnchor(_period, _anchor, delta);
        _showAllItems = false;
      });

  @override
  Widget build(BuildContext context) {
    final receipts = context.watch<ReceiptController>().receipts;
    final range = rangeFor(_period, _anchor);
    final report = ReportData.build(receipts, range, _period);
    final previous = ReportData.build(
      receipts,
      rangeFor(_period, shiftAnchor(_period, _anchor, -1)),
      _period,
    );
    final isCurrent = range.contains(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Raporlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          PillTabs<ReportPeriod>(
            values: ReportPeriod.values,
            selected: _period,
            labelOf: (p) => p.label,
            onChanged: (p) => setState(() {
              _period = p;
              _anchor = DateTime.now();
              _showAllItems = false;
            }),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _NavButton(
                tooltip: 'Önceki',
                icon: Icons.chevron_left_rounded,
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      rangeLabel(_period, range),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    if (!isCurrent)
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => setState(() => _anchor = DateTime.now()),
                        child: Text(switch (_period) {
                          ReportPeriod.daily => 'Bugüne dön',
                          ReportPeriod.weekly => 'Bu haftaya dön',
                          ReportPeriod.monthly => 'Bu aya dön',
                        }),
                      ),
                  ],
                ),
              ),
              _NavButton(
                tooltip: 'Sonraki',
                icon: Icons.chevron_right_rounded,
                onPressed: isCurrent ? null : () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SummaryCard(report: report, previous: previous, period: _period),
          if (report.count == 0)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: EmptyState(
                icon: Icons.insights_outlined,
                title: 'Bu dönemde harcama yok',
                message: 'Fiş ekledikçe harcamaların burada dönem dönem raporlanır.',
              ),
            )
          else ...[
            SectionHeader(
              title: switch (_period) {
                ReportPeriod.daily => 'Saatlere göre',
                ReportPeriod.weekly => 'Günlere göre',
                ReportPeriod.monthly => 'Günlere göre',
              },
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                child: SizedBox(height: 180, child: _TrendChart(buckets: report.buckets, period: _period)),
              ),
            ),
            const SectionHeader(title: 'Kategoriler'),
            _CategoryCard(report: report),
            const SectionHeader(title: 'Ürünler'),
            _ItemsCard(
              report: report,
              showAll: _showAllItems,
              onToggle: () => setState(() => _showAllItems = !_showAllItems),
            ),
            const SectionHeader(title: 'Mağazalar'),
            CardList(
              children: [
                for (final store in report.byStore.take(5))
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(store.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${store.count} fiş'),
                    trailing: Text(formatMoney(store.amount),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            SectionHeader(title: 'Bu dönemin fişleri (${report.count})'),
            CardList(children: [for (final r in report.receipts) ReceiptTile(receipt: r)]),
          ],
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.tooltip, required this.icon, required this.onPressed});

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: scheme.surface,
        disabledBackgroundColor: Colors.transparent,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        fixedSize: const Size(42, 42),
      ),
      icon: Icon(icon),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report, required this.previous, required this.period});

  final ReportData report;
  final ReportData previous;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previousLabel = switch (period) {
      ReportPeriod.daily => 'önceki güne',
      ReportPeriod.weekly => 'önceki haftaya',
      ReportPeriod.monthly => 'önceki aya',
    };

    Widget? comparison;
    if (previous.total > 0) {
      final change = (report.total - previous.total) / previous.total * 100;
      final up = change >= 0;
      // Harcamanın artması kötü (kırmızı), azalması iyi (yeşil).
      final color = up ? scheme.error : const Color(0xFF16A34A);
      comparison = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.trending_up : Icons.trending_down, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            '$previousLabel göre %${change.abs().toStringAsFixed(0)} ${up ? 'fazla' : 'az'}',
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Toplam harcama', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              formatMoney(report.total),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (comparison != null) ...[const SizedBox(height: 4), comparison],
            const SizedBox(height: 16),
            Row(
              children: [
                stat('Fiş sayısı', '${report.count}'),
                stat('Ortalama fiş', formatMoney(report.average)),
                stat('Toplam KDV', formatMoney(report.vat)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.buckets, required this.period});

  final List<ChartBucket> buckets;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = buckets.fold(0.0, (m, b) => b.value > m ? b.value : m);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;
    final barWidth = switch (period) {
      ReportPeriod.daily => 22.0,
      ReportPeriod.weekly => 22.0,
      ReportPeriod.monthly => 6.0,
    };

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return Text(
                  formatMoneyCompact(value).replaceAll(',00', ''),
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(buckets[i].label,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${buckets[group.x].tooltip}\n',
              TextStyle(color: scheme.onInverseSurface, fontSize: 11),
              children: [
                TextSpan(
                  text: formatMoney(rod.toY),
                  style: TextStyle(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buckets[i].value,
                  width: barWidth,
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(barWidth > 10 ? 7 : 3),
                  // Aylık görünümde 31 arka plan çubuğu kalabalık durur.
                  backDrawRodData: BackgroundBarChartRodData(
                    show: period != ReportPeriod.monthly,
                    toY: maxY,
                    color: scheme.primary.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.report});

  final ReportData report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: [
                    for (final share in report.byCategory)
                      PieChartSectionData(
                        value: share.amount <= 0 ? 0.0001 : share.amount,
                        color: ExpenseCategory.byId(share.key).color,
                        radius: 16,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (final share in report.byCategory)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: ExpenseCategory.byId(share.key).color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(ExpenseCategory.byId(share.key).label,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          Text(
                            '%${report.total <= 0 ? 0 : (share.amount / report.total * 100).round()}',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Text(formatMoney(share.amount),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.report, required this.showAll, required this.onToggle});

  final ReportData report;
  final bool showAll;
  final VoidCallback onToggle;

  static const _collapsedCount = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = report.items;
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Bu dönemdeki fişlerde ürün kalemi yok.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }
    final visible = showAll ? items : items.take(_collapsedCount).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            for (final item in visible)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            '${formatQty(item.quantity)} adet · ${item.receiptCount} fişte',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(item.total),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: item.total < 0 ? scheme.error : null,
                      ),
                    ),
                  ],
                ),
              ),
            if (items.length > _collapsedCount)
              TextButton(
                onPressed: onToggle,
                child: Text(showAll ? 'Daha az göster' : 'Tüm ürünleri göster (${items.length})'),
              ),
          ],
        ),
      ),
    );
  }
}
