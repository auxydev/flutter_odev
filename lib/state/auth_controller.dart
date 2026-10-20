import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/app_user.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._db) {
    final current = _db.session.get('current') as String?;
    final stored = current == null ? null : _db.users.get(current);
    if (stored != null) _user = AppUser.fromMap(stored as Map);
  }

  final AppDatabase _db;
  AppUser? _user;

  AppUser? get currentUser => _user;

  /// Başarılıysa null, değilse kullanıcıya gösterilecek hata mesajı döner.
  Future<String?> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final key = username.trim().toLowerCase();
    final mail = email.trim().toLowerCase();
    if (_db.users.containsKey(key)) return 'Bu kullanıcı adı zaten alınmış.';
    if (_findByEmail(mail) != null) return 'Bu e-posta adresiyle zaten bir hesap var.';

    final salt = _newSalt();
    final user = AppUser(
      username: username.trim(),
      email: mail,
      passwordHash: _hash(password, salt),
      salt: salt,
      createdAt: DateTime.now(),
    );
    await _db.users.put(key, user.toMap());
    await _startSession(user);
    return null;
  }

  Future<String?> login({required String identifier, required String password}) async {
    final id = identifier.trim().toLowerCase();
    final stored = _db.users.get(id) ?? _findByEmail(id);
    if (stored == null) return 'Kullanıcı bulunamadı.';
    final user = AppUser.fromMap(stored as Map);
    if (_hash(password, user.salt) != user.passwordHash) return 'Şifre hatalı.';
    await _startSession(user);
    return null;
  }

  Future<void> logout() async {
    await _db.session.delete('current');
    _user = null;
    notifyListeners();
  }

  Future<void> _startSession(AppUser user) async {
    await _db.session.put('current', user.username.toLowerCase());
    _user = user;
    notifyListeners();
  }

  Map<dynamic, dynamic>? _findByEmail(String email) {
    for (final value in _db.users.values) {
      final map = value as Map;
      if (map['email'] == email) return map;
    }
    return null;
  }

  static String _newSalt() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  static String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();
}
