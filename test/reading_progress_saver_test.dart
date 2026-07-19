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
  });

  tearDown(() async {
    await appDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saveNow persiste la página al cerrar/pausar', () async {
    final saver = ReadingProgressSaver(datasource);
    saver.attach(bookId: book.id!, initialPage: 1);
    saver.onPageChanged(12);
    await saver.saveNow();

    final updated = await datasource.findBookById(book.id!);
    expect(updated?.lastPageRead, 12);
    expect(updated?.lastReadAt, isNotNull);
    saver.dispose();
  });

  test('no escribe si no hubo cambio de página (saveIfNeeded)', () async {
    final saver = ReadingProgressSaver(datasource);
    saver.attach(bookId: book.id!, initialPage: 1);
    await saver.saveIfNeeded();
    final unchanged = await datasource.findBookById(book.id!);
    expect(unchanged?.lastPageRead, 1);
    expect(unchanged?.lastReadAt, isNull);
    saver.dispose();
  });

  test('no pierde página si cambia durante un guardado en vuelo', () async {
    final saver = ReadingProgressSaver(datasource);
    saver.attach(bookId: book.id!, initialPage: 1);
    saver.onPageChanged(5);
    final first = saver.saveNow();
    saver.onPageChanged(10);
    final second = saver.saveNow(page: 10);
    await Future.wait([first, second]);

    final updated = await datasource.findBookById(book.id!);
    expect(updated?.lastPageRead, 10);
    expect(saver.isDirty, isFalse);
    saver.dispose();
  });

  test('autosave diferido persiste tras cambio de página', () async {
    final saver = ReadingProgressSaver(
      datasource,
      autosaveDelay: const Duration(milliseconds: 40),
    );
    saver.attach(bookId: book.id!, initialPage: 1);
    saver.onPageChanged(7);

    await Future<void>.delayed(const Duration(milliseconds: 120));

    final updated = await datasource.findBookById(book.id!);
    expect(updated?.lastPageRead, 7);
    expect(saver.isDirty, isFalse);
    saver.dispose();
  });

  test('saveNow no escribe si la página no cambió', () async {
    final saver = ReadingProgressSaver(datasource);
    saver.attach(bookId: book.id!, initialPage: 1);
    await saver.saveNow(page: 1);

    final unchanged = await datasource.findBookById(book.id!);
    expect(unchanged?.lastPageRead, 1);
    expect(unchanged?.lastReadAt, isNull);
    expect(saver.isDirty, isFalse);
    saver.dispose();
  });

  test('saveNow forceTouch actualiza last_read_at sin cambiar página', () async {
    final saver = ReadingProgressSaver(datasource);
    saver.attach(bookId: book.id!, initialPage: 1);
    await saver.saveNow(page: 1, forceTouch: true);

    final updated = await datasource.findBookById(book.id!);
    expect(updated?.lastPageRead, 1);
    expect(updated?.lastReadAt, isNotNull);
    expect(saver.isDirty, isFalse);
    saver.dispose();
  });
}
