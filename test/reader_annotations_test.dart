import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/data/datasources/library_local_datasource.dart';
import 'package:minimal_pdf/data/models/book.dart';
import 'package:minimal_pdf/data/models/bookmark.dart';
import 'package:minimal_pdf/data/models/page_annotation.dart';
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

  test('addAnnotation guarda marcado y comentario en la página', () async {
    final highlight = await annotations.addAnnotation(
      pageNumber: 2,
      type: AnnotationType.highlight,
      x: 0.1,
      y: 0.2,
      width: 0.4,
      height: 0.05,
    );
    expect(highlight, isNotNull);
    expect(annotations.annotationsForPage(2), hasLength(1));

    final comment = await annotations.addAnnotation(
      pageNumber: 2,
      type: AnnotationType.comment,
      x: 0.7,
      y: 0.3,
      width: 0.1,
      height: 0.06,
      text: 'Revisar esto',
    );
    expect(comment?.text, 'Revisar esto');
    expect(annotations.annotationsForPage(2), hasLength(2));

    await annotations.deleteAnnotation(comment!);
    expect(annotations.annotationsForPage(2), hasLength(1));
  });

  test('toolbox selecciona y limpia herramienta activa', () {
    expect(annotations.toolboxVisible, isFalse);
    annotations.toggleToolbox();
    expect(annotations.toolboxVisible, isTrue);
    // Abrir la caja no auto-selecciona herramienta (el scroll sigue libre).
    expect(annotations.activeTool, AnnotationTool.none);

    annotations.selectTool(AnnotationTool.underline);
    expect(annotations.activeTool, AnnotationTool.underline);

    annotations.selectTool(AnnotationTool.underline);
    expect(annotations.activeTool, AnnotationTool.none);

    annotations.clearTool();
    expect(annotations.activeTool, AnnotationTool.none);

    annotations.setToolboxVisible(false);
    expect(annotations.toolboxVisible, isFalse);
    expect(annotations.activeTool, AnnotationTool.none);

    annotations.setToolboxVisible(true);
    expect(annotations.toolboxVisible, isTrue);
    expect(annotations.activeTool, AnnotationTool.none);

    annotations.selectTool(AnnotationTool.highlight);
    expect(annotations.activeTool, AnnotationTool.highlight);
  });

  test('toggleBookmark serializa toques concurrentes', () async {
    final first = annotations.toggleBookmark(8);
    final second = annotations.toggleBookmark(8);
    await Future.wait([first, second]);

    final rows = await datasource.listBookmarks(book.id!);
    final onPage = rows.where((b) => b.pageNumber == 8).length;
    expect(onPage, anyOf(0, 1));
    expect(annotations.error, isNull);
  });

  test('PdfTocEntry.fromPageCount genera índice navegable', () {
    final toc = PdfTocEntry.fromPageCount(
      3,
      titleForPage: (page) => 'Página $page',
    );
    expect(toc.map((e) => e.pageNumber), [1, 2, 3]);
    expect(toc.first.title, 'Página 1');
  });

  test('PdfTocEntry.forPage es O(1) sin lista completa', () {
    final entry = PdfTocEntry.forPage(42, title: 'Página 42');
    expect(entry.pageNumber, 42);
    expect(entry.title, 'Página 42');
  });

  test('PdfTocEntry.forPage usa fallback neutro sin título', () {
    final entry = PdfTocEntry.forPage(7);
    expect(entry.title, 'Page 7');
  });
}
