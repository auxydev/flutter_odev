import 'dart:async';
import 'dart:convert';

import '../data/app_database.dart';
import 'platform/platform_services.dart';

/// Hive veritabanının okunabilir JSON hâli (tarihler ISO-8601 metin olarak).
Map<String, dynamic> databaseSnapshot(AppDatabase db) {
  String? iso(Object? ms) =>
      ms is int ? DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String() : null;

  Map<String, dynamic> plain(Object? value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

  return {
    'exportedAt': DateTime.now().toIso8601String(),
    'session': {
      'currentUser': db.session.get('current'),
      'rememberedUser': db.session.get('remembered'),
    },
    'users': [
      for (final value in db.users.values)
        plain(value)..['createdAt'] = iso((value as Map)['createdAt']),
    ],
    'receipts': [
      for (final value in db.receipts.values)
        plain(value)
          ..['date'] = iso((value as Map)['date'])
          ..['createdAt'] = iso(value['createdAt']),
    ],
  };
}

String databaseJson(AppDatabase db) =>
    const JsonEncoder.withIndent('  ').convert(databaseSnapshot(db));

/// Veritabanı her değiştiğinde JSON dosyasını günceller (mobilde).
class DatabaseJsonMirror {
  DatabaseJsonMirror(this._db);

  final AppDatabase _db;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _debounce;
  String? lastPath;

  Future<void> start() async {
    for (final box in [_db.users, _db.receipts, _db.session]) {
      _subscriptions.add(box.watch().listen((_) => _schedule()));
    }
    await write();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), write);
  }

  Future<String?> write() async {
    try {
      lastPath = await writeDatabaseJsonFile(databaseJson(_db)) ?? lastPath;
    } catch (_) {
      // Dosyaya yazılamasa da uygulama çalışmaya devam etsin.
    }
    return lastPath;
  }
}
