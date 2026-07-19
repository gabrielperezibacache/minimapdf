import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/data/datasources/library_local_datasource.dart';
import 'package:minimal_pdf/data/models/book.dart';
import 'package:minimal_pdf/presentation/reader/reading_progress_saver.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase appDatabase;
  late LibraryLocalDatasource datasource;
  late Book book;
  late ReadingProgressSaver saver;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_reader_');
    appDatabase = AppDatabase(
      customFactory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'library.db'),
    );
    await appDatabase.open();
    datasource = LibraryLocalDatasource(LibraryDatabase(appDatabase));

    book = await datasource.insertBook(
      Book(
        title: 'Manual',
        filePath: p.join(tempDir.path, 'manual.pdf'),
        fileSize: 10,
        addedAt: DateTime(2026, 7, 1),
        lastPageRead: 1,
      ),
    );

    saver = ReadingProgressSaver(datasource);
    saver.attach(bookId: book.id!, initialPage: 1);
  });

  tearDown(() async {
    await appDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saveNow persiste la página al cerrar/pausar', () async {
    saver.onPageChanged(12);
    await saver.saveNow();

    final updated = await datasource.findBookById(book.id!);
    expect(updated?.lastPageRead, 12);
    expect(updated?.lastReadAt, isNotNull);
  });

  test('no escribe si no hubo cambio de página (saveIfNeeded)', () async {
    await saver.saveIfNeeded();
    final unchanged = await datasource.findBookById(book.id!);
    expect(unchanged?.lastPageRead, 1);
    expect(unchanged?.lastReadAt, isNull);
  });
}
