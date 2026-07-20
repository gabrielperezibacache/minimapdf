import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/core/preferences/app_preferences.dart';
import 'package:minimal_pdf/core/preferences/welcome_gate.dart';
import 'package:minimal_pdf/data/models/book.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase appDatabase;
  late LibraryDatabase libraryDatabase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_welcome_gate_');
    appDatabase = AppDatabase(
      customFactory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'test.db'),
    );
    await appDatabase.open();
    libraryDatabase = LibraryDatabase(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('primera apertura marca vista y pide mostrar bienvenida una vez', () async {
    final prefs = await AppPreferences.open();
    expect(prefs.hasSeenWelcome, isFalse);

    final show = await prepareWelcomeVisibility(
      preferences: prefs,
      libraryDatabase: libraryDatabase,
    );

    expect(show, isTrue);
    expect(prefs.hasSeenWelcome, isTrue);

    final again = await prepareWelcomeVisibility(
      preferences: prefs,
      libraryDatabase: libraryDatabase,
    );
    expect(again, isFalse);
  });

  test('instalación con libros existentes no muestra bienvenida', () async {
    await libraryDatabase.createBook(
      Book(
        title: 'Ya instalado',
        filePath: p.join(tempDir.path, 'ya.pdf'),
        fileSize: 4,
        addedAt: DateTime.now(),
      ),
    );

    final prefs = await AppPreferences.open();
    final show = await prepareWelcomeVisibility(
      preferences: prefs,
      libraryDatabase: libraryDatabase,
    );

    expect(show, isFalse);
    expect(prefs.hasSeenWelcome, isTrue);
  });

  test('si ya se vio, no vuelve a mostrar', () async {
    final prefs = await AppPreferences.open();
    await prefs.markWelcomeSeen();

    final show = await prepareWelcomeVisibility(
      preferences: prefs,
      libraryDatabase: libraryDatabase,
    );
    expect(show, isFalse);
  });
}
