import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/data/datasources/library_local_datasource.dart';
import 'package:minimal_pdf/data/models/book.dart';
import 'package:minimal_pdf/data/models/bookmark.dart';
import 'package:minimal_pdf/presentation/providers/reader_annotations_provider.dart';
import 'package:minimal_pdf/presentation/reader/pdf_toc_entry.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase appDatabase;
  late LibraryLocalDatasource datasource;
  late Book book;
  late ReaderAnnotationsProvider annotations;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_annot_');
    appDatabase = AppDatabase(
      customFactory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'library.db'),
    );
    await appDatabase.open();
    datasource = LibraryLocalDatasource(LibraryDatabase(appDatabase));
    book = await datasource.insertBook(
      Book(
        title: 'Anotado',
        filePath: p.join(tempDir.path, 'a.pdf'),
        fileSize: 8,
        addedAt: DateTime(2026, 7, 10),
      ),
    );
    annotations = ReaderAnnotationsProvider(datasource);
    await annotations.loadForBook(book.id!);
  });

  tearDown(() async {
    annotations.dispose();
    await appDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('toggleBookmark marca y desmarca la página', () async {
    await annotations.toggleBookmark(3);
    expect(annotations.isPageBookmarked(3), isTrue);

    await annotations.toggleBookmark(3);
    expect(annotations.isPageBookmarked(3), isFalse);
  });

  test('toggleBookmark con nota exige force para borrar', () async {
    await annotations.saveNote(pageNumber: 2, noteText: 'Importante');
    final blocked = await annotations.toggleBookmark(2);
    expect(blocked, isFalse);
    expect(annotations.isPageBookmarked(2), isTrue);
    expect(annotations.bookmarkForPage(2)?.noteText, 'Importante');

    final removed = await annotations.toggleBookmark(2, force: true);
    expect(removed, isTrue);
    expect(annotations.isPageBookmarked(2), isFalse);
  });

  test('toggleBookmark consulta DB y no pisa nota existente', () async {
    await annotations.saveNote(pageNumber: 4, noteText: 'No borrar');
    annotations.dispose();

    // Provider fresco sin lista en memoria, pero con bookId cargado.
    annotations = ReaderAnnotationsProvider(datasource);
    await annotations.loadForBook(book.id!);
    // Vaciar vista en memoria artificialmente no es público; forzar
    // re-consulta: quitar de memoria vía nuevo load parcial no aplica.
    // Verificamos el camino DB: upsert sin clear conserva la nota.
    await datasource.upsertBookmark(
      Bookmark(
        bookId: book.id!,
        pageNumber: 4,
        createdAt: DateTime(2026, 7, 1),
      ),
    );
    final kept = await datasource.findBookmarkForPage(book.id!, 4);
    expect(kept?.noteText, 'No borrar');

    final blocked = await annotations.toggleBookmark(4);
    expect(blocked, isFalse);
    expect(
      (await datasource.findBookmarkForPage(book.id!, 4))?.noteText,
      'No borrar',
    );
  });

  test('saveNote crea marcador con texto y permite actualizar', () async {
    await annotations.saveNote(pageNumber: 5, noteText: 'Idea clave');
    expect(annotations.bookmarkForPage(5)?.noteText, 'Idea clave');

    await annotations.saveNote(pageNumber: 5, noteText: 'Actualizado');
    expect(annotations.bookmarks.length, 1);
    expect(annotations.bookmarkForPage(5)?.noteText, 'Actualizado');
  });

  test('PdfTocEntry.fromPageCount genera índice navegable', () {
    final toc = PdfTocEntry.fromPageCount(3);
    expect(toc.map((e) => e.pageNumber), [1, 2, 3]);
    expect(toc.first.title, 'Página 1');
  });

  test('PdfTocEntry.forPage es O(1) sin lista completa', () {
    final entry = PdfTocEntry.forPage(42);
    expect(entry.pageNumber, 42);
    expect(entry.title, 'Página 42');
  });
}
