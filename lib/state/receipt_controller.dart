import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/receipt.dart';
import '../services/platform/platform_services.dart';

/// Giriş yapmış kullanıcının fişlerini yönetir.
class ReceiptController extends ChangeNotifier {
  ReceiptController(this._db);

  final AppDatabase _db;
  String? _owner;
  List<Receipt> _receipts = const [];

  String? get owner => _owner;

  /// Tarihe göre yeniden eskiye sıralı.
  List<Receipt> get receipts => _receipts;

  /// Kullanıcı değiştiğinde (giriş/çıkış) çağrılır.
  void setOwner(String? username) {
    final owner = username?.toLowerCase();
    if (owner == _owner) return;
    _owner = owner;
    _load();
  }

  Receipt? byId(String id) {
    for (final r in _receipts) {
      if (r.id == id) return r;
    }
    return null;
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(1 << 16).toRadixString(16)}';

  Future<void> save(Receipt receipt) async {
    await _db.receipts.put(receipt.id, receipt.toMap());
    _load();
    notifyListeners();
  }

  Future<void> delete(Receipt receipt) async {
    await _db.receipts.delete(receipt.id);
    await deleteReceiptImage(receipt.imagePath);
    _load();
    notifyListeners();
  }

  void _load() {
    if (_owner == null) {
      _receipts = const [];
      return;
    }
    _receipts = _db.receipts.values
        .map((m) => Receipt.fromMap(m as Map))
        .where((r) => r.owner == _owner)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}
