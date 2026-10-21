import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

bool get ocrSupported => Platform.isAndroid || Platform.isIOS;

/// Fotoğraftaki metni ML Kit ile (cihaz üzerinde, internetsiz) okur.
///
/// ML Kit fişteki ürün adı sütunu ile fiyat sütununu çoğu zaman ayrı bloklar
/// olarak döndürür. Bu yüzden satırları dikey konumlarına göre yeniden
/// birleştirip "EKMEK  *7,50" gibi gerçek fiş satırlarını elde ediyoruz.
Future<String> recognizeReceiptText(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
    final lines = <({Rect box, String text})>[
      for (final block in result.blocks)
        for (final line in block.lines) (box: line.boundingBox, text: line.text),
    ];
    return _rebuildRows(lines).join('\n');
  } finally {
    await recognizer.close();
  }
}

List<String> _rebuildRows(List<({Rect box, String text})> lines) {
  if (lines.isEmpty) return const [];
  lines.sort((a, b) => a.box.center.dy.compareTo(b.box.center.dy));

  final rows = <List<({Rect box, String text})>>[];
  for (final line in lines) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null) {
      final rowCenter = row.map((l) => l.box.center.dy).reduce((a, b) => a + b) / row.length;
      final rowHeight = row.map((l) => l.box.height).reduce((a, b) => a + b) / row.length;
      final tolerance = (rowHeight < line.box.height ? rowHeight : line.box.height) * 0.6;
      if ((line.box.center.dy - rowCenter).abs() <= tolerance) {
        row.add(line);
        continue;
      }
    }
    rows.add([line]);
  }

  return [
    for (final row in rows)
      (row..sort((a, b) => a.box.left.compareTo(b.box.left))).map((l) => l.text).join('  '),
  ];
}

/// Seçilen fotoğrafı uygulamanın kalıcı klasörüne kopyalar (önbellek temizlense de kalsın).
Future<String?> persistReceiptImage(String sourcePath, String receiptId) async {
  final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/receipts');
  await dir.create(recursive: true);
  final ext = sourcePath.contains('.') ? sourcePath.substring(sourcePath.lastIndexOf('.')) : '.jpg';
  final target = await File(sourcePath).copy('${dir.path}/$receiptId$ext');
  return target.path;
}

Future<void> deleteReceiptImage(String? path) async {
  if (path == null) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}

/// Veritabanının JSON kopyasını yazar. Android'de dosya yöneticisinden ve adb ile
/// erişilebilen `/sdcard/Android/data/<paket>/files/` klasörü kullanılır.
Future<String?> writeDatabaseJsonFile(String json) async {
  final dir = Platform.isAndroid
      ? (await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory())
      : await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/fis_takip_db.json');
  await file.writeAsString(json, flush: true);
  return file.path;
}

Widget receiptImage(String path, {BoxFit fit = BoxFit.cover}) => Image.file(
      File(path),
      fit: fit,
      errorBuilder: (context, error, stack) => const Center(
        child: Icon(Icons.broken_image_outlined, size: 40),
      ),
    );
