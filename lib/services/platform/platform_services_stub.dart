import 'package:flutter/widgets.dart';

/// Web'de cihaz üzerinde OCR yok; fişler metin yapıştırarak veya elle girilir.
bool get ocrSupported => false;

Future<String> recognizeReceiptText(String imagePath) =>
    throw UnsupportedError('Fiş okuma bu platformda desteklenmiyor.');

Future<String?> persistReceiptImage(String sourcePath, String receiptId) async => null;

Future<void> deleteReceiptImage(String? path) async {}

Widget receiptImage(String path, {BoxFit fit = BoxFit.cover}) => const SizedBox.shrink();
