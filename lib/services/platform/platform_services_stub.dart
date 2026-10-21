import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web'de cihaz üzerinde OCR yok; fişler metin yapıştırarak veya elle girilir.
bool get ocrSupported => false;

Future<String> recognizeReceiptText(String imagePath) =>
    throw UnsupportedError('Fiş okuma bu platformda desteklenmiyor.');

Future<String?> persistReceiptImage(String sourcePath, String receiptId) async => null;

Future<void> deleteReceiptImage(String? path) async {}

/// Web'de tarayıcının çevrimiçi durumuna bakılır.
Future<bool> hasInternetConnection() async => web.window.navigator.onLine;

/// Web'de dosya sistemi yok; JSON uygulama içindeki ekrandan görüntülenir.
Future<String?> writeDatabaseJsonFile(String json) async => null;

Widget receiptImage(String path, {BoxFit fit = BoxFit.cover}) => const SizedBox.shrink();
