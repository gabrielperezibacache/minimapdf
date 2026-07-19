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
import 'package:shared_preferences/shared_preferences.dart';
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
    SharedPreferences.setMockInitialValues({});
    preferences = await AppPreferences.open();
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_welcome_');
    appDatabase = AppDatabase(
      customFactory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'test.db'),
    );
    await appDatabase.open();
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
    expect(find.text('Privacidad de verdad'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Omitir'), findsOneWidget);
    expect(find.text('Biblioteca'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('navegación explica biblioteca y lector con Atrás',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.obsidian,
        home: WelcomeScreen(onFinished: () {}),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca local'), findsOneWidget);
    expect(find.text('Así funciona Minimal PDF'), findsOneWidget);
    expect(find.text('Atrás'), findsOneWidget);
    expect(find.text('Importar · Colecciones · Descargas'), findsOneWidget);

    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    expect(find.text('Privacidad de verdad'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Lector Hermes Obsidian'), findsOneWidget);
    expect(find.text('Empezar a leer'), findsOneWidget);
    expect(find.text('Omitir'), findsNothing);
    expect(find.text('Rápido · Cómodo · Sin distracciones'), findsOneWidget);
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

  testWidgets('Empezar a leer completa el onboarding', (WidgetTester tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.obsidian,
        home: WelcomeScreen(onFinished: () => finished = true),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar a leer'));
    await tester.pump();

    expect(finished, isTrue);
  });
}
