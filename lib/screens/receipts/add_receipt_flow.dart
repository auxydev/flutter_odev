import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/platform/platform_services.dart';
import '../../services/receipt_parser.dart';
import 'receipt_form_screen.dart';

enum _AddMethod { camera, gallery, paste, manual }

/// "+" butonuna basıldığında açılan fiş ekleme akışı.
Future<void> startAddReceipt(BuildContext context) async {
  final method = await showModalBottomSheet<_AddMethod>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => const _AddMethodSheet(),
  );
  if (method == null || !context.mounted) return;

  switch (method) {
    case _AddMethod.camera:
      await _scan(context, ImageSource.camera);
    case _AddMethod.gallery:
      await _scan(context, ImageSource.gallery);
    case _AddMethod.paste:
      final text = await showDialog<String>(
        context: context,
        builder: (_) => const _PasteTextDialog(),
      );
      if (text == null || text.trim().isEmpty || !context.mounted) return;
      await _openForm(context, const ReceiptParser().parse(text));
    case _AddMethod.manual:
      await _openForm(context, null);
  }
}

Future<void> _scan(BuildContext context, ImageSource source) async {
  final messenger = ScaffoldMessenger.of(context);
  final XFile? image;
  try {
    image = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 95);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Görsel alınamadı: $e')));
    return;
  }
  if (image == null || !context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Fiş okunuyor...')),
          ],
        ),
      ),
    ),
  );

  ParsedReceipt? parsed;
  String? error;
  try {
    final text = await recognizeReceiptText(image.path);
    parsed = const ReceiptParser().parse(text);
  } catch (e) {
    error = '$e';
  }
  navigator.pop();
  if (!context.mounted) return;

  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text('Fiş okunamadı: $error')));
  } else if (parsed!.items.isEmpty && parsed.total == null) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Fişte okunabilir tutar bulunamadı. Bilgileri elle tamamlayabilirsin.'),
    ));
  }
  await _openForm(context, parsed, imagePath: image.path);
}

Future<void> _openForm(BuildContext context, ParsedReceipt? parsed, {String? imagePath}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReceiptFormScreen(parsed: parsed, imagePath: imagePath),
    ),
  );
}

class _AddMethodSheet extends StatelessWidget {
  const _AddMethodSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget option(_AddMethod method, IconData icon, String title, String subtitle) => ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Icon(icon),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
          onTap: () => Navigator.of(context).pop(method),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Fiş ekle',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (ocrSupported) ...[
              option(_AddMethod.camera, Icons.photo_camera_outlined, 'Fişi tara',
                  'Kamerayla fotoğrafını çek, otomatik okunsun'),
              option(_AddMethod.gallery, Icons.photo_library_outlined, 'Galeriden seç',
                  'Daha önce çektiğin fiş fotoğrafını oku'),
            ],
            option(_AddMethod.paste, Icons.content_paste_outlined, 'Fiş metnini yapıştır',
                'Kopyaladığın fiş metni otomatik ayrıştırılsın'),
            option(_AddMethod.manual, Icons.edit_note_outlined, 'Elle gir',
                'Mağaza, tarih ve tutarı kendin yaz'),
            if (!ocrSupported)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fotoğraftan fiş okuma mobil uygulamada kullanılabilir.',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
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

class _PasteTextDialog extends StatefulWidget {
  const _PasteTextDialog();

  @override
  State<_PasteTextDialog> createState() => _PasteTextDialogState();
}

class _PasteTextDialogState extends State<_PasteTextDialog> {
  final _controller = TextEditingController();

  static const _sample = '''BİM BİRLEŞİK MAĞAZALAR A.Ş.
ESENTEPE MAH. BÜYÜKDERE CAD. NO:45
TARİH: 19.10.2026  SAAT: 09:41
FİŞ NO: 0127
2 AD X 15,00
EKMEK          %01  *30,00
YUMURTA 10LU   %01  *79,50
BEYAZ PEYNİR   %01  *145,90
ÇAY 1KG        %20  *189,00
TOPKDV              *35,57
TOPLAM              *444,40
KREDİ KARTI         *444,40''';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fiş metnini yapıştır'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 8,
              maxLines: 14,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(hintText: 'TOPLAM *123,45 ...'),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _controller.text = _sample),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('Örnek fiş doldur'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Ayrıştır'),
        ),
      ],
    );
  }
}
