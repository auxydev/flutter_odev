// Emülatördeki/telefondaki uygulama veritabanını proje klasörüne çeker.
//
//   dart run tool/db_cek.dart          -> bir kez çeker
//   dart run tool/db_cek.dart --izle   -> değiştikçe sürekli günceller (Ctrl+C ile durur)
//
// Uygulama, veritabanı her değiştiğinde JSON kopyasını cihazda şu dosyaya yazar:
//   /sdcard/Android/data/com.kagan.fis_takip/files/fis_takip_db.json
// Bu betik dosyayı `database/fis_takip_db.json` olarak projeye kopyalar.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const devicePath = '/sdcard/Android/data/com.kagan.fis_takip/files/fis_takip_db.json';
final localFile = File('database/fis_takip_db.json');

Future<void> main(List<String> args) async {
  final adb = _findAdb();
  if (adb == null) {
    stderr.writeln('adb bulunamadı. ANDROID_HOME ayarla ya da platform-tools\'u PATH\'e ekle.');
    exit(1);
  }

  if (!args.contains('--izle')) {
    final changed = await _pull(adb);
    if (changed == null) exit(1);
    stdout.writeln('✓ ${localFile.path} güncellendi.');
    return;
  }

  stdout.writeln('Veritabanı izleniyor → ${localFile.path}  (durdurmak için Ctrl+C)');
  while (true) {
    final changed = await _pull(adb, quiet: true);
    if (changed == true) {
      final time = DateTime.now().toIso8601String().substring(11, 19);
      stdout.writeln('[$time] değişiklik alındı: ${_summary()}');
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}

/// Değiştiyse true, aynıysa false, hata olursa null döner.
Future<bool?> _pull(String adb, {bool quiet = false}) async {
  final result = await Process.run(adb, ['exec-out', 'cat', devicePath], stdoutEncoding: utf8);
  final content = result.stdout as String;
  if (result.exitCode != 0 || !content.trimLeft().startsWith('{')) {
    if (!quiet) {
      stderr.writeln('Dosya okunamadı. Emülatör açık mı ve uygulama en az bir kez çalıştı mı?\n'
          '${result.stderr}');
    }
    return null;
  }
  final old = localFile.existsSync() ? localFile.readAsStringSync() : null;
  if (old == content) return false;
  localFile.parent.createSync(recursive: true);
  localFile.writeAsStringSync(content);
  return true;
}

String _summary() {
  final db = jsonDecode(localFile.readAsStringSync()) as Map<String, dynamic>;
  return '${(db['users'] as List).length} kullanıcı, ${(db['receipts'] as List).length} fiş';
}

String? _findAdb() {
  final exe = Platform.isWindows ? 'adb.exe' : 'adb';
  final roots = [
    Platform.environment['ANDROID_HOME'],
    Platform.environment['ANDROID_SDK_ROOT'],
    if (Platform.isWindows) '${Platform.environment['LOCALAPPDATA']}\\Android\\Sdk',
    if (Platform.isMacOS) '${Platform.environment['HOME']}/Library/Android/sdk',
    if (Platform.isLinux) '${Platform.environment['HOME']}/Android/Sdk',
  ];
  for (final root in roots.whereType<String>()) {
    final candidate = File('$root${Platform.pathSeparator}platform-tools${Platform.pathSeparator}$exe');
    if (candidate.existsSync()) return candidate.path;
  }
  // PATH'te varsa doğrudan kullan.
  final which = Process.runSync(Platform.isWindows ? 'where' : 'which', ['adb']);
  return which.exitCode == 0 ? (which.stdout as String).split(RegExp(r'\r?\n')).first.trim() : null;
}
