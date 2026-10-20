import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense_category.dart';
import '../../models/receipt.dart';
import '../../state/receipt_controller.dart';
import '../../utils/format.dart';
import '../../utils/text_utils.dart';
import '../../widgets/common.dart';
import 'add_receipt_flow.dart';
import 'receipt_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  TextStyle _chipLabel(BuildContext context, bool selected) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontWeight: FontWeight.w600,
      color: selected ? scheme.onPrimary : scheme.onSurface,
    );
  }

  bool _matches(Receipt r) {
    if (_category != null && r.category != _category) return false;
    if (_query.isEmpty) return true;
    final q = normalizeKey(_query);
    return normalizeKey(r.storeName).contains(q) ||
        r.items.any((i) => normalizeKey(i.name).contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<ReceiptController>().receipts;
    final receipts = all.where(_matches).toList();
    final usedCategories = {for (final r in all) r.category};

    // Aylara göre grupla (liste zaten yeniden eskiye sıralı).
    final groups = <DateTime, List<Receipt>>{};
    for (final r in receipts) {
      groups.putIfAbsent(DateTime(r.date.year, r.date.month), () => []).add(r);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş Fişler'),
        actions: [
          IconButton(
            tooltip: 'Fiş ekle',
            onPressed: () => startAddReceipt(context),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: all.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Geçmiş fişin yok',
                message: 'Eklediğin fişler burada tarih sırasıyla listelenir.',
                action: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => startAddReceipt(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Fiş ekle'),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Mağaza veya ürün ara',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Temizle',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Tümü'),
                        labelStyle: _chipLabel(context, _category == null),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                      for (final c in ExpenseCategory.all.where((c) => usedCategories.contains(c.id)))
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            avatar: Icon(
                              c.icon,
                              size: 18,
                              color: _category == c.id
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : c.color,
                            ),
                            label: Text(c.label),
                            labelStyle: _chipLabel(context, _category == c.id),
                            selected: _category == c.id,
                            onSelected: (sel) => setState(() => _category = sel ? c.id : null),
                          ),
                        ),
                    ],
                  ),
                ),
                if (receipts.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off,
                    title: 'Sonuç yok',
                    message: 'Aramana uyan fiş bulunamadı.',
                  ),
                for (final entry in groups.entries) ...[
                  SectionHeader(
                    title: formatMonthYear(entry.key),
                    action: Text(
                      formatMoney(entry.value.fold(0.0, (s, r) => s + r.total)),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  CardList(
                    children: [
                      for (final r in entry.value)
                        Dismissible(
                          key: ValueKey(r.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: Icon(Icons.delete_outline,
                                color: Theme.of(context).colorScheme.onErrorContainer),
                          ),
                          confirmDismiss: (_) => confirmDeleteReceipt(context, r),
                          onDismissed: (_) => context.read<ReceiptController>().delete(r),
                          child: ReceiptTile(receipt: r),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
