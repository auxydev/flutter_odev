import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'services/db_export.dart';
import 'state/auth_controller.dart';
import 'state/receipt_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  Intl.defaultLocale = 'tr_TR';
  final db = await AppDatabase.open();
  // Veritabanı her değiştiğinde fis_takip_db.json dosyası güncellenir.
  final jsonMirror = DatabaseJsonMirror(db);
  unawaited(jsonMirror.start());

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: db),
        Provider.value(value: jsonMirror),
        ChangeNotifierProvider(create: (_) => AuthController(db)),
        ChangeNotifierProxyProvider<AuthController, ReceiptController>(
          create: (_) => ReceiptController(db),
          update: (_, auth, receipts) =>
              receipts!..setOwner(auth.currentUser?.username),
        ),
      ],
      child: const FisTakipApp(),
    ),
  );
}

class FisTakipApp extends StatelessWidget {
  const FisTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthController, bool>((a) => a.currentUser != null);
    return MaterialApp(
      title: 'Fiş Takip',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: loggedIn ? const HomeShell() : const LoginScreen(),
    );
  }
}
