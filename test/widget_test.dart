import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/constants/app_constants.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/core/preferences/app_preferences.dart';
import 'package:minimal_pdf/main.dart';
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
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_widget_');
    appDatabase = AppDatabase(
      customFactory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'test.db'),
    );
    await appDatabase.open();
    preferences = await AppPreferences.open(directory: tempDir);
    preferences.markWelcomeSeen();
  });

  tearDown(() async {
    await appDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Biblioteca muestra título y FAB de importación',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MinimalPdfApp(
        appDatabase: appDatabase,
        libraryDatabase: LibraryDatabase(appDatabase),
        preferences: preferences,
      ),
    );
    await tester.pump(); // ejecuta post-frame → LibraryProvider.load()

    // Sqflite FFI usa tiempo real; hay que salir del fake-async del tester.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text(AppConstants.appName), findsWidgets);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.byTooltip('Importar PDF'), findsOneWidget);
    expect(find.byTooltip('Descargas / navegador'), findsOneWidget);
    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
