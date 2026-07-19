import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_constants.dart';
import 'core/database/app_database.dart';
import 'core/database/library_database.dart';
import 'core/preferences/app_preferences.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/library_local_datasource.dart';
import 'data/datasources/pdf_download_service.dart';
import 'data/datasources/pdf_import_service.dart';
import 'presentation/library/library_screen.dart';
import 'presentation/onboarding/welcome_screen.dart';
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
  final preferences = await AppPreferences.open();

  runApp(
    MinimalPdfApp(
      appDatabase: appDatabase,
      libraryDatabase: LibraryDatabase(appDatabase),
      preferences: preferences,
    ),
  );
}

class MinimalPdfApp extends StatelessWidget {
  const MinimalPdfApp({
    super.key,
    required this.appDatabase,
    required this.libraryDatabase,
    required this.preferences,
  });

  final AppDatabase appDatabase;
  final LibraryDatabase libraryDatabase;
  final AppPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<AppPreferences>.value(value: preferences),
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
      child: _MinimalPdfRoot(
        showWelcomeInitially: !preferences.hasSeenWelcome,
      ),
    );
  }
}

class _MinimalPdfRoot extends StatefulWidget {
  const _MinimalPdfRoot({required this.showWelcomeInitially});

  final bool showWelcomeInitially;

  @override
  State<_MinimalPdfRoot> createState() => _MinimalPdfRootState();
}

class _MinimalPdfRootState extends State<_MinimalPdfRoot> {
  late bool _showWelcome = widget.showWelcomeInitially;

  void _finishWelcome() {
    context.read<AppPreferences>().markWelcomeSeen();
    setState(() => _showWelcome = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeOption = context.watch<ThemeProvider>().option;

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(themeOption),
      home: _showWelcome
          ? WelcomeScreen(onFinished: _finishWelcome)
          : const LibraryScreen(),
    );
  }
}
