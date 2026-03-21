import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'dart:io' show Platform;
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/store_provider.dart';
import 'core/providers/warehouse_provider.dart';
import 'core/providers/notification_provider.dart';
import 'core/router/app_router.dart';
import 'data/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Platform-specific SQLite init
  if (kIsWeb) {
    // Web: use persistent FFI (IndexedDB)
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Desktop: sqflite needs the FFI factory
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Android / iOS: sqflite uses its own native driver — no override needed

  await initializeDateFormatting('vi', null);

  // Pre-warm the database (creates tables + seeds data on first run)
  await DatabaseService.instance.database;

  // Đảm bảo tài khoản demo cho tất cả roles tồn tại (safe to call every launch)
  await DatabaseService.instance.ensureDemoUsers();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => WarehouseProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MinhChauApp(),
    ),
  );
}

class MinhChauApp extends StatelessWidget {
  const MinhChauApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final router = AppRouter.createRouter(authProvider);

    return MaterialApp.router(
      title: 'Minh Châu - Tạp Hóa',
      theme: AppTheme.theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi', 'VN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
    );
  }
}
