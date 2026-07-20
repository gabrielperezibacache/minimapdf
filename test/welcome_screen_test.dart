import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/l10n_test_app.dart';
import 'package:minimal_pdf/core/constants/app_constants.dart';
import 'package:minimal_pdf/l10n/app_localizations.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/core/preferences/app_preferences.dart';
import 'package:minimal_pdf/core/preferences/welcome_gate.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/main.dart';
import 'package:minimal_pdf/presentation/onboarding/welcome_screen.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/mock_external_pdf_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase appDatabase;
  late LibraryDatabase libraryDatabase;
  late AppPreferences preferences;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    mockExternalPdfOpenChannels();
    SharedPreferences.setMockInitialValues({
      // Biblioteca post-onboarding se aserta en español.
      'app_locale': 'es',
    });
    preferences = await AppPreferences.open();
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_welcome_');
    appDatabase = AppDatabase(
      customFactory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'test.db'),
    );
    await appDatabase.open();
    libraryDatabase = LibraryDatabase(appDatabase);
  });

  tearDown(() async {
    clearExternalPdfOpenChannelMocks();
    await appDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// sqflite en testWidgets requiere [WidgetTester.runAsync].
  Future<bool> prepareWelcome(WidgetTester tester) {
    return tester.runAsync(() {
      return prepareWelcomeVisibility(
        preferences: preferences,
        libraryDatabase: libraryDatabase,
      );
    }).then((value) => value!);
  }

  testWidgets('primera apertura muestra bienvenida con valor y funciones',
      (WidgetTester tester) async {
    final showWelcome = await prepareWelcome(tester);
    expect(showWelcome, isTrue);
    expect(preferences.hasSeenWelcome, isTrue);

    await tester.pumpWidget(
      MinimalPdfApp(
        appDatabase: appDatabase,
        libraryDatabase: libraryDatabase,
        preferences: preferences,
        showWelcome: showWelcome,
      ),
    );
    await tester.pump();

    expect(find.text(AppConstants.appName), findsWidgets);
    expect(
      find.text('Bienvenido a una lectura offline, privada y sin ruido.'),
      findsOneWidget,
    );
    expect(find.text('Privacidad de verdad'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Omitir'), findsOneWidget);
    expect(find.text('Biblioteca'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('segunda apertura no muestra bienvenida aunque no se terminó',
      (WidgetTester tester) async {
    final first = await prepareWelcome(tester);
    expect(first, isTrue);

    // Simula cierre sin Omitir / Empezar a leer.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final prefsAgain = await AppPreferences.open();
    final second = await tester.runAsync(() {
      return prepareWelcomeVisibility(
        preferences: prefsAgain,
        libraryDatabase: libraryDatabase,
      );
    });
    expect(second, isFalse);

    await tester.pumpWidget(
      MinimalPdfApp(
        appDatabase: appDatabase,
        libraryDatabase: libraryDatabase,
        preferences: prefsAgain,
        showWelcome: second,
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('Omitir'), findsNothing);
    expect(find.text('Biblioteca'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('navegación explica biblioteca y lector con Atrás',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.ebony,
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: WelcomeScreen(onFinished: () {}),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca local'), findsOneWidget);
    expect(find.text('Así funciona Minimal PDF'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);
    expect(find.text('Importar · Colecciones · Descargas'), findsOneWidget);

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Privacidad de verdad'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Lector Ébano'), findsOneWidget);
    expect(find.text('Empezar'), findsOneWidget);
    expect(find.text('Omitir'), findsNothing);
    expect(find.text('Rápido · Cómodo · Sin distracciones'), findsOneWidget);
  });

  testWidgets('PDF externo pendiente omite la bienvenida',
      (WidgetTester tester) async {
    clearExternalPdfOpenChannelMocks();
    mockExternalPdfOpenChannels(initialPdfPath: '/tmp/external_open.pdf');

    final showWelcome = await prepareWelcome(tester);

    await tester.pumpWidget(
      MinimalPdfApp(
        appDatabase: appDatabase,
        libraryDatabase: libraryDatabase,
        preferences: preferences,
        showWelcome: showWelcome,
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Omitir'), findsNothing);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(preferences.hasSeenWelcome, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('omitir marca bienvenida y abre biblioteca',
      (WidgetTester tester) async {
    final showWelcome = await prepareWelcome(tester);

    await tester.pumpWidget(
      MinimalPdfApp(
        appDatabase: appDatabase,
        libraryDatabase: libraryDatabase,
        preferences: preferences,
        showWelcome: showWelcome,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Omitir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.byTooltip('Importar PDF'), findsOneWidget);

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(preferences.hasSeenWelcome, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final prefsAgain = await AppPreferences.open();
    expect(prefsAgain.hasSeenWelcome, isTrue);
    final showAgain = await tester.runAsync(() {
      return prepareWelcomeVisibility(
        preferences: prefsAgain,
        libraryDatabase: libraryDatabase,
      );
    });
    expect(showAgain, isFalse);

    await tester.pumpWidget(
      MinimalPdfApp(
        appDatabase: appDatabase,
        libraryDatabase: libraryDatabase,
        preferences: prefsAgain,
        showWelcome: showAgain,
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Omitir'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Empezar a leer completa el onboarding', (WidgetTester tester) async {
    var finished = false;
    await tester.pumpWidget(
      l10nTestApp(
        theme: AppTheme.ebony,
        home: WelcomeScreen(onFinished: () => finished = true),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar'));
    await tester.pump();

    expect(finished, isTrue);
  });
}
