import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense_category.dart';
import '../../models/receipt.dart';
import '../../services/platform/platform_services.dart';
import '../../services/receipt_parser.dart';
import '../../state/receipt_controller.dart';
import '../../utils/format.dart';
import '../../widgets/pill_tabs.dart';
import 'image_viewer.dart';

/// Yeni fişi (taranmış / yapıştırılmış / boş) veya mevcut fişi düzenler.
class ReceiptFormScreen extends StatefulWidget {
  const ReceiptFormScreen({super.key, this.existing, this.parsed, this.imagePath});

  final Receipt? existing;
  final ParsedReceipt? parsed;

  /// Yeni taranan fişin geçici görsel yolu.
  final String? imagePath;

  @override
  State<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ItemRow {
  _ItemRow({String name = '', double quantity = 1, double? total})
      : name = TextEditingController(text: name),
        quantity = TextEditingController(text: formatQty(quantity)),
        total = TextEditingController(text: total == null ? '' : toInputNumber(total));

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController total;

  void dispose() {
    name.dispose();
    quantity.dispose();
    total.dispose();
  }
}

class _ReceiptFormScreenState extends State<ReceiptFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _store;
  late final TextEditingController _total;
  late final TextEditingController _vat;
  late DateTime _date;
  late String _category;
  String? _payment;
  late final List<_ItemRow> _items;

  /// Kullanıcı toplamı elle değiştirmediyse kalemler değiştikçe toplam güncellenir.
  late bool _autoTotal;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  String? get _imagePath => widget.existing?.imagePath ?? widget.imagePath;
  String? get _rawText => widget.existing?.rawText ?? widget.parsed?.rawText;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final p = widget.parsed;
    _store = TextEditingController(text: e?.storeName ?? p?.storeName ?? '');
    final total = e?.total ?? p?.total;
    _total = TextEditingController(text: total == null ? '' : toInputNumber(total));
    final vat = e?.vat ?? p?.vat;
    _vat = TextEditingController(text: vat == null ? '' : toInputNumber(vat));
    _date = e?.date ?? p?.date ?? DateTime.now();
    _category = e?.category ?? p?.category ?? ExpenseCategory.fallbackId;
    _payment = e?.paymentMethod ?? p?.paymentMethod;
    _items = [
      for (final item in e?.items ?? p?.items ?? const <ReceiptItem>[])
        _ItemRow(name: item.name, quantity: item.quantity, total: item.total),
    ];
    _autoTotal = total == null;
  }

  @override
  void dispose() {
    _store.dispose();
    _total.dispose();
    _vat.dispose();
    for (final row in _items) {
      row.dispose();
    }
    super.dispose();
  }

  double get _itemsSum =>
      _items.fold(0.0, (sum, row) => sum + (parseUserNumber(row.total.text) ?? 0));

  void _onItemsChanged() {
    if (_autoTotal) _total.text = _items.isEmpty ? '' : toInputNumber(_itemsSum);
    setState(() {});
  }

  void _addItem() {
    setState(() => _items.add(_ItemRow()));
  }

  void _removeItem(int index) {
    _items.removeAt(index).dispose();
    _onItemsChanged();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (picked == null) return;
    setState(() => _date = DateTime(_date.year, _date.month, _date.day, picked.hour, picked.minute));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final controller = context.read<ReceiptController>();
    final navigator = Navigator.of(context);
    final id = widget.existing?.id ?? ReceiptController.newId();

    var imagePath = widget.existing?.imagePath;
    if (!_isEdit && widget.imagePath != null) {
      try {
        imagePath = await persistReceiptImage(widget.imagePath!, id);
      } catch (_) {
        imagePath = null; // Görsel kopyalanamasa da fiş kaydedilsin.
      }
    }

    final items = <ReceiptItem>[
      for (final row in _items)
        if (row.name.text.trim().isNotEmpty)
          ReceiptItem(
            name: row.name.text.trim(),
            quantity: parseUserNumber(row.quantity.text) ?? 1,
            total: parseUserNumber(row.total.text) ?? 0,
          ),
    ];

    await controller.save(Receipt(
      id: id,
      owner: controller.owner!,
      storeName: _store.text.trim(),
      date: _date,
      category: _category,
      items: items,
      total: parseUserNumber(_total.text)!,
      vat: parseUserNumber(_vat.text),
      paymentMethod: _payment,
      receiptNo: widget.existing?.receiptNo ?? widget.parsed?.receiptNo,
      imagePath: imagePath,
      rawText: _rawText,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    ));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEdit ? 'Fiş güncellendi.' : 'Fiş kaydedildi.')),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = parseUserNumber(_total.text);
    final mismatch = _items.isNotEmpty && total != null && (total - _itemsSum).abs() > 0.009;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Fişi düzenle' : 'Fiş bilgileri'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            if (widget.parsed != null && !_isEdit) _InfoBanner(parsed: widget.parsed!),
            if (_imagePath != null) ...[
              GestureDetector(
                onTap: () => openImageViewer(context, _imagePath!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(height: 150, child: receiptImage(_imagePath!)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _store,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Mağaza / işletme',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Mağaza adını gir.' : null,
              onChanged: (v) {
                // Elle girişte mağaza adına göre kategori öner.
                if (_category == ExpenseCategory.fallbackId) {
                  final guess = ExpenseCategory.guess(v, '');
                  if (guess != _category) setState(() => _category = guess);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _TapField(
                    label: 'Tarih',
                    icon: Icons.calendar_today_outlined,
                    value: formatDateShort(_date),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _TapField(
                    label: 'Saat',
                    icon: Icons.schedule_outlined,
                    value: TimeOfDay.fromDateTime(_date).format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              key: ValueKey(_category),
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                for (final c in ExpenseCategory.all)
                  DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(c.icon, color: c.color, size: 20),
                        const SizedBox(width: 10),
                        Text(c.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            Text('Ödeme', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            PillTabs<String?>(
              values: const ['Nakit', 'Kart', null],
              selected: _payment,
              labelOf: (v) => v ?? 'Belirtilmemiş',
              iconOf: (v) => switch (v) {
                'Nakit' => Icons.payments_outlined,
                'Kart' => Icons.credit_card_rounded,
                _ => null,
              },
              onChanged: (v) => setState(() => _payment = v),
            ),

            // --- Kalemler
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Ürünler (${_items.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Ürün ekle'),
                  ),
                ],
              ),
            ),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'Ürün eklemek isteğe bağlı. Raporlarda ürün bazında döküm için ürünleri ekleyebilirsin.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            for (var i = 0; i < _items.length; i++)
              _ItemEditor(
                key: ObjectKey(_items[i]),
                row: _items[i],
                onChanged: _onItemsChanged,
                onRemove: () => _removeItem(i),
              ),

            // --- Tutarlar
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vat,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'KDV', suffixText: '₺'),
                    validator: (v) => (v == null || v.trim().isEmpty || parseUserNumber(v) != null)
                        ? null
                        : 'Geçersiz',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _total,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Toplam',
                      suffixText: '₺',
                      suffixIcon: _items.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Ürünlerden hesapla',
                              icon: const Icon(Icons.calculate_outlined),
                              onPressed: () {
                                _autoTotal = true;
                                _onItemsChanged();
                              },
                            ),
                    ),
                    onChanged: (_) => setState(() => _autoTotal = false),
                    validator: (v) {
                      final value = parseUserNumber(v ?? '');
                      if (value == null) return 'Toplamı gir.';
                      if (value <= 0) return 'Sıfırdan büyük olmalı.';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            if (mismatch)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: scheme.tertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ürünlerin toplamı ${formatMoney(_itemsSum)}, fiş toplamı ${formatMoney(total)}. '
                        'Okunan değerleri kontrol et.',
                        style: TextStyle(color: scheme.tertiary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            if (_rawText != null && _rawText!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: ExpansionTile(
                  shape: const Border(),
                  leading: const Icon(Icons.text_snippet_outlined),
                  title: const Text('Fişten okunan metin'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    SelectableText(
                      _rawText!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Icon(Icons.check),
            label: Text(_isEdit ? 'Değişiklikleri kaydet' : 'Fişi kaydet'),
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.parsed});

  final ParsedReceipt parsed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final found = parsed.items.isNotEmpty || parsed.total != null;
    final accent = found ? scheme.primary : scheme.tertiary;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(11)),
            child: Icon(found ? Icons.auto_awesome : Icons.edit_note, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              found
                  ? '${parsed.items.length} ürün okundu. Kaydetmeden önce bilgileri kontrol et.'
                  : 'Fişten bilgi çıkarılamadı, lütfen elle tamamla.',
              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  const _TapField({required this.label, required this.icon, required this.value, required this.onTap});

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({super.key, required this.row, required this.onChanged, required this.onRemove});

  final _ItemRow row;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    const dense = InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: row.name,
              textCapitalization: TextCapitalization.sentences,
              decoration: dense.copyWith(hintText: 'Ürün adı'),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 56,
            child: TextFormField(
              controller: row.quantity,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: dense.copyWith(hintText: 'Adet'),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 96,
            child: TextFormField(
              controller: row.total,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: dense.copyWith(hintText: 'Tutar', suffixText: '₺'),
              onChanged: (_) => onChanged(),
              validator: (v) => row.name.text.trim().isNotEmpty && parseUserNumber(v ?? '') == null
                  ? 'Tutar?'
                  : null,
            ),
          ),
          IconButton(
            tooltip: 'Ürünü sil',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
