import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/data/models/models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase appDatabase;
  late LibraryDatabase library;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_db_');
    appDatabase = AppDatabase(
      customFactory: databaseFactoryFfi,
      databasePath: p.join(tempDir.path, 'library.db'),
    );
    await appDatabase.open();
    library = LibraryDatabase(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Collections CRUD', () {
    test('crear, leer, actualizar y borrar', () async {
      final created = await library.createCollection(
        Collection(name: 'Ensayos', createdAt: DateTime(2026, 1, 1)),
      );
      expect(created.id, isNotNull);

      final fetched = await library.getCollectionById(created.id!);
      expect(fetched?.name, 'Ensayos');

      await library.updateCollection(created.copyWith(name: 'Ensayos 2'));
      expect((await library.getCollectionById(created.id!))?.name, 'Ensayos 2');

      expect(await library.deleteCollection(created.id!), 1);
      expect(await library.getCollectionById(created.id!), isNull);
    });
  });

  group('Books CRUD', () {
    test('crear, listar recientes, actualizar progreso y borrar', () async {
      final collection = await library.createCollection(
        Collection(name: 'Tech', createdAt: DateTime(2026, 1, 2)),
      );

      final book = await library.createBook(
        Book(
          title: 'Clean Architecture',
          filePath: '/docs/clean.pdf',
          fileSize: 2048,
          addedAt: DateTime(2026, 1, 3),
          author: 'Uncle Bob',
          tags: const ['architecture', 'dart'],
          collectionId: collection.id,
        ),
      );
      expect(book.id, isNotNull);

      final byPath = await library.getBookByFilePath('/docs/clean.pdf');
      expect(byPath?.title, 'Clean Architecture');
      expect(byPath?.tags, ['architecture', 'dart']);
      expect(byPath?.collectionId, collection.id);

      await library.updateReadingProgress(
        bookId: book.id!,
        lastPageRead: 42,
        lastReadAt: DateTime(2026, 1, 4, 10),
      );

      final recent = await library.getRecentBooks();
      expect(recent, isNotEmpty);
      expect(recent.first.lastPageRead, 42);
      expect(recent.first.lastReadAt, DateTime(2026, 1, 4, 10));

      final inCollection =
          await library.getBooksByCollection(collection.id);
      expect(inCollection.length, 1);

      expect(await library.deleteBook(book.id!), 1);
      expect(await library.getBookById(book.id!), isNull);
    });

    test('borrar colección deja collection_id en null (SET NULL)', () async {
      final collection = await library.createCollection(
        Collection(name: 'Temp', createdAt: DateTime(2026, 2, 1)),
      );
      final book = await library.createBook(
        Book(
          title: 'Nota',
          filePath: '/docs/nota.pdf',
          fileSize: 100,
          addedAt: DateTime(2026, 2, 1),
          collectionId: collection.id,
        ),
      );

      await library.deleteCollection(collection.id!);
      final updated = await library.getBookById(book.id!);
      expect(updated?.collectionId, isNull);
    });
  });

  group('Bookmarks CRUD', () {
    test('upsertBookmark actualiza nota sin duplicar página', () async {
      final book = await library.createBook(
        Book(
          title: 'Notas',
          filePath: '/docs/notas.pdf',
          fileSize: 20,
          addedAt: DateTime(2026, 3, 5),
        ),
      );

      final first = await library.upsertBookmark(
        Bookmark(
          bookId: book.id!,
          pageNumber: 4,
          noteText: 'Uno',
          createdAt: DateTime(2026, 3, 5),
        ),
      );
      final second = await library.upsertBookmark(
        Bookmark(
          bookId: book.id!,
          pageNumber: 4,
          noteText: 'Dos',
          createdAt: DateTime(2026, 3, 6),
        ),
      );

      expect(second.id, first.id);
      expect(
        (await library.getBookmarkForPage(book.id!, 4))?.noteText,
        'Dos',
      );
      expect(await library.getBookmarksForBook(book.id!), hasLength(1));

      // Re-marcar sin nota no debe borrar la existente.
      await library.upsertBookmark(
        Bookmark(
          bookId: book.id!,
          pageNumber: 4,
          createdAt: DateTime(2026, 3, 7),
        ),
      );
      expect(
        (await library.getBookmarkForPage(book.id!, 4))?.noteText,
        'Dos',
      );

      await library.upsertBookmark(
        Bookmark(
          bookId: book.id!,
          pageNumber: 4,
          createdAt: DateTime(2026, 3, 8),
        ),
        clearNoteText: true,
      );
      expect(
        (await library.getBookmarkForPage(book.id!, 4))?.noteText,
        isNull,
      );
    });

    test('crear, listar, actualizar y cascade al borrar libro', () async {
      final book = await library.createBook(
        Book(
          title: 'PDF',
          filePath: '/docs/a.pdf',
          fileSize: 10,
          addedAt: DateTime(2026, 3, 1),
        ),
      );

      final bookmark = await library.createBookmark(
        Bookmark(
          bookId: book.id!,
          pageNumber: 12,
          noteText: 'Idea clave',
          createdAt: DateTime(2026, 3, 2),
        ),
      );
      expect(bookmark.id, isNotNull);

      final listed = await library.getBookmarksForBook(book.id!);
      expect(listed.length, 1);
      expect(listed.first.noteText, 'Idea clave');

      await library.updateBookmark(
        bookmark.copyWith(noteText: 'Actualizado'),
      );
      expect(
        (await library.getBookmarksForBook(book.id!)).first.noteText,
        'Actualizado',
      );

      await library.deleteBook(book.id!);
      expect(await library.getBookmarksForBook(book.id!), isEmpty);
    });
  });
}
