import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense_category.dart';
import '../../models/receipt.dart';
import '../../services/platform/platform_services.dart';
import '../../state/receipt_controller.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'image_viewer.dart';
import 'receipt_form_screen.dart';

Future<bool> confirmDeleteReceipt(BuildContext context, Receipt receipt) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Fiş silinsin mi?'),
      content: Text('${receipt.storeName} – ${formatMoney(receipt.total)} tutarındaki fiş kalıcı olarak silinecek.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class ReceiptDetailScreen extends StatelessWidget {
  const ReceiptDetailScreen({super.key, required this.receiptId});

  final String receiptId;

  @override
  Widget build(BuildContext context) {
    final receipt = context.watch<ReceiptController>().byId(receiptId);
    if (receipt == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Fiş bulunamadı.')));
    }
    final category = ExpenseCategory.byId(receipt.category);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiş detayı'),
        actions: [
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ReceiptFormScreen(existing: receipt)),
            ),
          ),
          IconButton(
            tooltip: 'Sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final controller = context.read<ReceiptController>();
              final navigator = Navigator.of(context);
              if (!await confirmDeleteReceipt(context, receipt)) return;
              navigator.pop();
              await controller.delete(receipt);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CategoryAvatar(categoryId: receipt.category, size: 56),
                  const SizedBox(height: 12),
                  Text(receipt.storeName,
                      textAlign: TextAlign.center,
                      style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(formatDateTime(receipt.date),
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  Text(formatMoney(receipt.total),
                      style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Chip(
                        avatar: Icon(category.icon, size: 18, color: category.color),
                        label: Text(category.label),
                      ),
                      if (receipt.paymentMethod != null)
                        Chip(
                          avatar: Icon(
                            receipt.paymentMethod == 'Kart' ? Icons.credit_card : Icons.payments_outlined,
                            size: 18,
                          ),
                          label: Text(receipt.paymentMethod!),
                        ),
                      if (receipt.receiptNo != null) Chip(label: Text('Fiş no: ${receipt.receiptNo}')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (receipt.imagePath != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => openImageViewer(context, receipt.imagePath!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(height: 180, child: receiptImage(receipt.imagePath!)),
              ),
            ),
          ],
          SectionHeader(title: 'Ürünler (${receipt.items.length})'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  if (receipt.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Bu fiş için ürün girilmemiş.',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                  for (final item in receipt.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                if (item.quantity != 1)
                                  Text(
                                    '${formatQty(item.quantity)} x ${formatMoney(item.unitPrice)}',
                                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
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
                  const Divider(height: 20),
                  if (receipt.vat != null) _AmountRow(label: 'KDV', value: receipt.vat!),
                  _AmountRow(label: 'Toplam', value: receipt.total, bold: true),
                ],
              ),
            ),
          ),
          if (receipt.rawText != null && receipt.rawText!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                shape: const Border(),
                leading: const Icon(Icons.text_snippet_outlined),
                title: const Text('Fişten okunan metin'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  SelectableText(receipt.rawText!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value, this.bold = false});

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(formatMoney(value), style: style),
        ],
      ),
    );
  }
}
