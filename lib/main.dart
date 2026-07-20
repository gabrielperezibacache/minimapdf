import 'dart:async';
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
import 'core/preferences/welcome_gate.dart';
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
  final libraryDatabase = LibraryDatabase(appDatabase);
  final showWelcome = await prepareWelcomeVisibility(
    preferences: preferences,
    libraryDatabase: libraryDatabase,
  );

  runApp(
    MinimalPdfApp(
      appDatabase: appDatabase,
      libraryDatabase: libraryDatabase,
      preferences: preferences,
      showWelcome: showWelcome,
    ),
  );
}

class MinimalPdfApp extends StatelessWidget {
  const MinimalPdfApp({
    super.key,
    required this.appDatabase,
    required this.libraryDatabase,
    this.preferences,
    this.showWelcome,
  });

  final AppDatabase appDatabase;
  final LibraryDatabase libraryDatabase;
  final AppPreferences? preferences;

  /// Si es null (tests), se deriva de [AppPreferences.hasSeenWelcome].
  final bool? showWelcome;

  @override
  Widget build(BuildContext context) {
    final welcome = showWelcome ??
        (preferences != null && !preferences!.hasSeenWelcome);

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
        ChangeNotifierProvider<ExternalPdfOpenService>(
          create: (_) => ExternalPdfOpenService(),
        ),
      ],
      child: _MinimalPdfRoot(showWelcomeInitially: welcome),
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
  bool _externalBootstrapStarted = false;
  ExternalPdfOpenService? _externalOpen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapExternalPdfOpen());
    });
  }

  @override
  void dispose() {
    _externalOpen?.removeListener(_onExternalOpenForWelcome);
    super.dispose();
  }

  void _onExternalOpenForWelcome() {
    final service = _externalOpen;
    if (service == null || !service.hasQueued || !_showWelcome) return;
    unawaited(_finishWelcome());
  }

  /// Arranca el puente nativo pronto: si el SO abre un PDF en frío,
  /// omitimos la bienvenida para no bloquear el documento.
  Future<void> _bootstrapExternalPdfOpen() async {
    if (_externalBootstrapStarted || !mounted) return;
    _externalBootstrapStarted = true;

    final service = context.read<ExternalPdfOpenService>();
    _externalOpen = service;
    service.addListener(_onExternalOpenForWelcome);
    try {
      await service.start();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('_bootstrapExternalPdfOpen start: $e');
      }
      return;
    }
    if (!mounted) return;

    if (service.hasQueued && _showWelcome) {
      await _finishWelcome();
    }
  }

  Future<void> _finishWelcome() async {
    if (_finishingWelcome || !_showWelcome) return;
    _finishingWelcome = true;
    _externalOpen?.removeListener(_onExternalOpenForWelcome);
    final prefs = context.read<AppPreferences?>();
    try {
      // Cinturón de seguridad: el flag ya se marca en prepareWelcomeVisibility.
      await prefs?.markWelcomeSeen();
    } catch (_) {
      // No bloqueamos el acceso a la biblioteca si falla la persistencia.
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
