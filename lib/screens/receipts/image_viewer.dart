import 'package:flutter/material.dart';

import '../../services/platform/platform_services.dart';

void openImageViewer(BuildContext context, String path) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Fiş görseli', style: TextStyle(color: Colors.white)),
        ),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(child: receiptImage(path, fit: BoxFit.contain)),
        ),
      ),
    ),
  );
}
