import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/constants/app_constants.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/core/preferences/app_preferences.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/main.dart';
import 'package:minimal_pdf/presentation/onboarding/welcome_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase appDatabase;
  late AppPreferences preferences;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_welcome_');
    appDatabase = AppDatabase(
      customFactory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'test.db'),
    );
    await appDatabase.open();
    preferences = await AppPreferences.open(directory: tempDir);
  });

  tearDown(() async {
    await appDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('primera apertura muestra bienvenida con valor y funciones',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MinimalPdfApp(
        appDatabase: appDatabase,
        libraryDatabase: LibraryDatabase(appDatabase),
        preferences: preferences,
      ),
    );
    await tester.pump();

    expect(find.text(AppConstants.appName), findsWidgets);
    expect(
      find.text('Bienvenido a una lectura offline, privada y sin ruido.'),
      findsOneWidget,
    );
    expect(find.text('Tu biblioteca, solo tuya'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Omitir'), findsOneWidget);
    expect(find.text('Biblioteca'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('páginas explican lector y descargas', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.obsidian,
        home: WelcomeScreen(onFinished: () {}),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Lectura rápida y cómoda'), findsOneWidget);
    expect(find.text('Así funciona Minimal PDF'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Descargas con privacidad'), findsOneWidget);
    expect(find.text('Empezar a leer'), findsOneWidget);
    expect(
      find.text('Pago único · 100% offline · Cero analíticas'),
      findsWidgets,
    );
  });

  testWidgets('omitir marca bienvenida y abre biblioteca',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MinimalPdfApp(
        appDatabase: appDatabase,
        libraryDatabase: LibraryDatabase(appDatabase),
        preferences: preferences,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Omitir'));
    await tester.pump();

    expect(preferences.hasSeenWelcome, isTrue);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.byTooltip('Importar PDF'), findsOneWidget);

    // Completa el load() de LibraryProvider (sqflite FFI / tiempo real).
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final prefsAgain = await AppPreferences.open(directory: tempDir);
    expect(prefsAgain.hasSeenWelcome, isTrue);

    await tester.pumpWidget(
      MinimalPdfApp(
        appDatabase: appDatabase,
        libraryDatabase: LibraryDatabase(appDatabase),
        preferences: prefsAgain,
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
}
