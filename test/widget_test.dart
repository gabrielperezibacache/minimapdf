import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/constants/app_constants.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/core/preferences/app_preferences.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:minimal_pdf/main.dart';
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
    SharedPreferences.setMockInitialValues({
      'has_seen_welcome': true,
    });
    preferences = await AppPreferences.open();
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_widget_');
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

  Future<void> pumpLibrary(WidgetTester tester) async {
    await tester.pumpWidget(
      MinimalPdfApp(
        appDatabase: appDatabase,
        libraryDatabase: LibraryDatabase(appDatabase),
        preferences: preferences,
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  testWidgets('Biblioteca muestra título y FAB de importación',
      (WidgetTester tester) async {
    await pumpLibrary(tester);

    expect(find.text(AppConstants.appName), findsWidgets);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(
      find.text('Buscar por título, autor o etiqueta'),
      findsOneWidget,
    );
    expect(find.byTooltip('Importar PDF'), findsOneWidget);
    expect(find.byTooltip('Descargas / navegador'), findsOneWidget);
    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('selector de tema aplica Claro y persiste', (tester) async {
    await pumpLibrary(tester);

    await tester.tap(find.byTooltip('Tema'));
    await tester.pumpAndSettle();

    expect(find.text('Claro'), findsWidgets);
    expect(find.text('Sepia'), findsWidgets);
    expect(find.text('Ébano'), findsWidgets);

    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<AppThemeOption>, 'Claro'),
    );
    await tester.pumpAndSettle();

    expect(preferences.themeOption, AppThemeOption.light);
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.scaffoldBackgroundColor, const Color(0xFFF4EEE7));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
