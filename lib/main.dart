import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_constants.dart';
import 'core/database/app_database.dart';
import 'core/database/library_database.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/library_local_datasource.dart';
import 'data/datasources/pdf_download_service.dart';
import 'data/datasources/pdf_import_service.dart';
import 'presentation/library/library_screen.dart';
import 'presentation/providers/downloader_provider.dart';
import 'presentation/providers/library_provider.dart';
import 'presentation/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sqflite nativo solo en móvil; en escritorio usamos FFI.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await PdfDownloadService.ensureNativeInitialized();

  final appDatabase = AppDatabase();
  await appDatabase.open();

  runApp(
    MinimalPdfApp(
      appDatabase: appDatabase,
      libraryDatabase: LibraryDatabase(appDatabase),
    ),
  );
}

class MinimalPdfApp extends StatelessWidget {
  const MinimalPdfApp({
    super.key,
    required this.appDatabase,
    required this.libraryDatabase,
  });

  final AppDatabase appDatabase;
  final LibraryDatabase libraryDatabase;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<AppDatabase>.value(value: appDatabase),
        Provider<LibraryDatabase>.value(value: libraryDatabase),
        Provider<LibraryLocalDatasource>(
          create: (context) => LibraryLocalDatasource(
            context.read<LibraryDatabase>(),
          ),
        ),
        Provider<PdfImportService>(
          create: (context) => PdfImportService(
            context.read<LibraryLocalDatasource>(),
          ),
        ),
        Provider<PdfDownloadService>(
          create: (context) => PdfDownloadService(
            context.read<LibraryLocalDatasource>(),
          ),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider<LibraryProvider>(
          create: (context) => LibraryProvider(
            datasource: context.read<LibraryLocalDatasource>(),
            importService: context.read<PdfImportService>(),
          ),
        ),
        ChangeNotifierProvider<DownloaderProvider>(
          create: (context) => DownloaderProvider(
            context.read<PdfDownloadService>(),
          ),
        ),
      ],
      child: const _MinimalPdfRoot(),
    );
  }
}

class _MinimalPdfRoot extends StatelessWidget {
  const _MinimalPdfRoot();

  @override
  Widget build(BuildContext context) {
    final themeOption = context.watch<ThemeProvider>().option;

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(themeOption),
      home: const LibraryScreen(),
    );
  }
}
