import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'l10n/app_localizations.dart';
import 'presentation/library/library_screen.dart';
import 'presentation/onboarding/welcome_screen.dart';
import 'presentation/providers/downloader_provider.dart';
import 'presentation/providers/library_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'services/external_pdf_open_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sqflite nativo solo en móvil; en escritorio usamos FFI.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await PdfDownloadService.ensureNativeInitialized();

  final preferences = await AppPreferences.open();
  final appDatabase = AppDatabase();
  await appDatabase.open();

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
    this.preferences,
  });

  final AppDatabase appDatabase;
  final LibraryDatabase libraryDatabase;
  final AppPreferences? preferences;

  @override
  Widget build(BuildContext context) {
    final showWelcome =
        preferences != null && !preferences!.hasSeenWelcome;

    return MultiProvider(
      providers: [
        Provider<AppPreferences?>.value(value: preferences),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(preferences: preferences),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(preferences: preferences),
        ),
        Provider<AppDatabase>(
          create: (_) => appDatabase,
          dispose: (_, db) => db.close(),
        ),
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
            preferences: preferences,
          ),
        ),
        ChangeNotifierProvider<DownloaderProvider>(
          create: (context) => DownloaderProvider(
            context.read<PdfDownloadService>(),
          ),
        ),
        Provider<ExternalPdfOpenService>(
          create: (_) => ExternalPdfOpenService(),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: _MinimalPdfRoot(showWelcomeInitially: showWelcome),
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
  bool _finishingWelcome = false;

  Future<void> _finishWelcome() async {
    if (_finishingWelcome || !_showWelcome) return;
    _finishingWelcome = true;
    final prefs = context.read<AppPreferences?>();
    try {
      await prefs?.markWelcomeSeen();
    } catch (_) {
      // Si falla la persistencia, no bloqueamos el acceso a la biblioteca;
      // la bienvenida podría repetirse en el próximo arranque.
    }
    if (!mounted) return;
    setState(() => _showWelcome = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeOption = context.watch<ThemeProvider>().option;
    final locale = context.watch<LocaleProvider>().locale;
    final theme = AppTheme.of(themeOption);
    final overlay = AppTheme.systemUiFor(themeOption);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              boldText: false,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: _showWelcome
              ? WelcomeScreen(
                  key: const ValueKey<String>('welcome'),
                  onFinished: _finishWelcome,
                )
              : const LibraryScreen(
                  key: ValueKey<String>('library'),
                ),
        ),
      ),
    );
  }
}
