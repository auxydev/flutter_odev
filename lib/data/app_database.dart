import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Yerel veritabanı (Hive). Android'de dosyada, web'de IndexedDB'de saklanır.
class AppDatabase {
  AppDatabase._(this.users, this.receipts, this.session);

  /// anahtar: küçük harf kullanıcı adı, değer: AppUser.toMap()
  final Box<dynamic> users;

  /// anahtar: fiş id, değer: Receipt.toMap()
  final Box<dynamic> receipts;

  /// Oturum bilgisi ('current' -> giriş yapmış kullanıcı)
  final Box<dynamic> session;

  static Future<AppDatabase> open() async {
    await Hive.initFlutter('fis_takip');
    return AppDatabase._(
      await Hive.openBox<dynamic>('users'),
      await Hive.openBox<dynamic>('receipts'),
      await Hive.openBox<dynamic>('session'),
    );
  }
}
