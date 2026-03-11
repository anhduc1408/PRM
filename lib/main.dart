import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/store_provider.dart';
import 'core/router/app_router.dart';
import 'data/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Platform-specific SQLite init
  if (kIsWeb) {
    // No web worker — runs SQLite in main thread, compatible with :memory: path
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
  } else {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await initializeDateFormatting('vi', null);

  // Pre-warm the database (creates tables + seeds data on first run)
  await DatabaseService.instance.database;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
      ],
      child: const MixueApp(),
    ),
  );
}

class MixueApp extends StatelessWidget {
  const MixueApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final router = AppRouter.createRouter(authProvider);

    return MaterialApp.router(
      title: 'Mixue Manager',
      theme: AppTheme.theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
