import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/app_user.dart';

/// Şifre sıfırlama isteğinin sonucu.
typedef ResetRequest = ({String? error, String? code, String? username});

class AuthController extends ChangeNotifier {
  AuthController(this._db) {
    // Yalnızca "Beni hatırla" ile giriş yapılmışsa oturum kalıcıdır.
    final current = _db.session.get('current') as String?;
    final stored = current == null ? null : _db.users.get(current);
    if (stored != null) _user = AppUser.fromMap(stored as Map);
  }

  final AppDatabase _db;
  AppUser? _user;

  AppUser? get currentUser => _user;

  /// "Beni hatırla" ile son giriş yapan kullanıcı (giriş ekranında önceden doldurulur).
  String? get rememberedIdentifier => _db.session.get('remembered') as String?;

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
    await _startSession(user, remember: true);
    return null;
  }

  Future<String?> login({
    required String identifier,
    required String password,
    bool remember = true,
  }) async {
    final stored = _findUser(identifier);
    if (stored == null) return 'Kullanıcı bulunamadı.';
    final user = AppUser.fromMap(stored);
    if (_hash(password, user.salt) != user.passwordHash) return 'Şifre hatalı.';
    await _startSession(user, remember: remember);
    return null;
  }

  Future<void> logout() async {
    await _db.session.delete('current');
    _user = null;
    notifyListeners();
  }

  Future<void> _startSession(AppUser user, {required bool remember}) async {
    if (remember) {
      await _db.session.put('current', user.username.toLowerCase());
      await _db.session.put('remembered', user.username);
    } else {
      // Oturum yalnızca bellekte; uygulama kapanınca tekrar giriş istenir.
      await _db.session.delete('current');
      await _db.session.delete('remembered');
    }
    _user = user;
    notifyListeners();
  }

  // --- Şifremi unuttum (e-posta servisi olmadığı için kod ekranda gösterilir) ---

  static const otpValidity = Duration(minutes: 3);
  static const _maxOtpAttempts = 5;

  String? _resetUserKey;
  String? _otp;
  DateTime? _otpExpiresAt;
  int _otpAttempts = 0;
  bool _otpVerified = false;

  DateTime? get otpExpiresAt => _otpExpiresAt;

  /// Kullanıcıyı bulur ve 6 haneli doğrulama kodu üretir.
  ResetRequest requestPasswordReset(String identifier) {
    final stored = _findUser(identifier);
    if (stored == null) return (error: 'Bu bilgilerle kayıtlı kullanıcı bulunamadı.', code: null, username: null);

    final random = Random.secure();
    _resetUserKey = (stored['username'] as String).toLowerCase();
    _otp = List.generate(6, (_) => random.nextInt(10)).join();
    _otpExpiresAt = DateTime.now().add(otpValidity);
    _otpAttempts = 0;
    _otpVerified = false;
    return (error: null, code: _otp, username: stored['username'] as String);
  }

  /// Başarılıysa null, değilse hata mesajı döner.
  String? verifyOtp(String code) {
    if (_otp == null || _otpExpiresAt == null) return 'Önce doğrulama kodu iste.';
    if (DateTime.now().isAfter(_otpExpiresAt!)) return 'Kodun süresi doldu. Yeni kod iste.';
    if (_otpAttempts >= _maxOtpAttempts) return 'Çok fazla hatalı deneme. Yeni kod iste.';
    if (code.trim() != _otp) {
      _otpAttempts++;
      final left = _maxOtpAttempts - _otpAttempts;
      return left > 0 ? 'Kod hatalı. $left deneme hakkın kaldı.' : 'Çok fazla hatalı deneme. Yeni kod iste.';
    }
    _otpVerified = true;
    return null;
  }

  /// Kod doğrulandıktan sonra yeni şifreyi kaydeder.
  Future<String?> resetPassword(String newPassword) async {
    final key = _resetUserKey;
    if (!_otpVerified || key == null) return 'Doğrulama tamamlanmadı.';
    final stored = _db.users.get(key);
    if (stored == null) return 'Kullanıcı bulunamadı.';

    final old = AppUser.fromMap(stored as Map);
    final salt = _newSalt();
    final updated = AppUser(
      username: old.username,
      email: old.email,
      passwordHash: _hash(newPassword, salt),
      salt: salt,
      createdAt: old.createdAt,
    );
    await _db.users.put(key, updated.toMap());
    cancelPasswordReset();
    return null;
  }

  void cancelPasswordReset() {
    _resetUserKey = null;
    _otp = null;
    _otpExpiresAt = null;
    _otpAttempts = 0;
    _otpVerified = false;
  }

  Map<dynamic, dynamic>? _findUser(String identifier) {
    final id = identifier.trim().toLowerCase();
    return (_db.users.get(id) as Map?) ?? _findByEmail(id);
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
