import 'package:sqflite/sqflite.dart';

import '../../data/models/models.dart';
import 'app_database.dart';
import 'database_config.dart';

/// Servicio CRUD local para libros, colecciones y marcadores.
class LibraryDatabase {
  LibraryDatabase(this._appDatabase);

  final AppDatabase _appDatabase;

  Database get _db => _appDatabase.database;

  // ---------------------------------------------------------------------------
  // Collections
  // ---------------------------------------------------------------------------

  Future<Collection> createCollection(Collection collection) async {
    final id = await _db.insert(
      DatabaseConfig.tableCollections,
      collection.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return collection.copyWith(id: id);
  }

  Future<Collection?> getCollectionById(int id) async {
    final rows = await _db.query(
      DatabaseConfig.tableCollections,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Collection.fromMap(rows.first);
  }

  Future<List<Collection>> getAllCollections() async {
    final rows = await _db.query(
      DatabaseConfig.tableCollections,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Collection.fromMap).toList();
  }

  Future<int> updateCollection(Collection collection) async {
    final id = collection.id;
    if (id == null) {
      throw ArgumentError('Collection.id es obligatorio para actualizar');
    }
    return _db.update(
      DatabaseConfig.tableCollections,
      collection.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCollection(int id) async {
    return _db.delete(
      DatabaseConfig.tableCollections,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Books
  // ---------------------------------------------------------------------------

  Future<Book> createBook(Book book) async {
    final id = await _db.insert(
      DatabaseConfig.tableBooks,
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return book.copyWith(id: id);
  }

  Future<Book?> getBookById(int id) async {
    final rows = await _db.query(
      DatabaseConfig.tableBooks,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  Future<Book?> getBookByFilePath(String filePath) async {
    final rows = await _db.query(
      DatabaseConfig.tableBooks,
      where: 'file_path = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  /// Libros de biblioteca: primero por última lectura, luego por alta.
  ///
  /// Si [limit] es null, devuelve todos (sin truncar silenciosamente).
  Future<List<Book>> getRecentBooks({int? limit}) async {
    final rows = await _db.query(
      DatabaseConfig.tableBooks,
      orderBy: 'last_read_at IS NULL, last_read_at DESC, added_at DESC',
      limit: limit,
    );
    return rows.map(Book.fromMap).toList();
  }

  Future<List<Book>> getAllBooks() async {
    final rows = await _db.query(
      DatabaseConfig.tableBooks,
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map(Book.fromMap).toList();
  }

  Future<List<Book>> getBooksByCollection(int? collectionId) async {
    if (collectionId == null) {
      final rows = await _db.query(
        DatabaseConfig.tableBooks,
        where: 'collection_id IS NULL',
        orderBy: 'title COLLATE NOCASE ASC',
      );
      return rows.map(Book.fromMap).toList();
    }

    final rows = await _db.query(
      DatabaseConfig.tableBooks,
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map(Book.fromMap).toList();
  }

  Future<int> updateBook(Book book) async {
    final id = book.id;
    if (id == null) {
      throw ArgumentError('Book.id es obligatorio para actualizar');
    }
    return _db.update(
      DatabaseConfig.tableBooks,
      book.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateReadingProgress({
    required int bookId,
    required int lastPageRead,
    DateTime? lastReadAt,
  }) async {
    return _db.update(
      DatabaseConfig.tableBooks,
      {
        'last_page_read': lastPageRead,
        'last_read_at': (lastReadAt ?? DateTime.now()).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<int> deleteBook(int id) async {
    return _db.delete(
      DatabaseConfig.tableBooks,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Bookmarks (base para Paso 5)
  // ---------------------------------------------------------------------------

  Future<Bookmark> createBookmark(Bookmark bookmark) async {
    final id = await _db.insert(
      DatabaseConfig.tableBookmarks,
      bookmark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return bookmark.copyWith(id: id);
  }

  Future<Bookmark?> getBookmarkForPage(int bookId, int pageNumber) async {
    final rows = await _db.query(
      DatabaseConfig.tableBookmarks,
      where: 'book_id = ? AND page_number = ?',
      whereArgs: [bookId, pageNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Bookmark.fromMap(rows.first);
  }

  Future<List<Bookmark>> getBookmarksForBook(int bookId) async {
    final rows = await _db.query(
      DatabaseConfig.tableBookmarks,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'page_number ASC',
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<int> updateBookmark(Bookmark bookmark) async {
    final id = bookmark.id;
    if (id == null) {
      throw ArgumentError('Bookmark.id es obligatorio para actualizar');
    }
    return _db.update(
      DatabaseConfig.tableBookmarks,
      bookmark.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Crea o actualiza el marcador de una página (única por libro+página).
  ///
  /// Si [clearNoteText] es false y [bookmark.noteText] es null, se conserva
  /// la nota existente (evita borrados accidentales al re-marcar).
  Future<Bookmark> upsertBookmark(
    Bookmark bookmark, {
    bool clearNoteText = false,
  }) async {
    final existing = await getBookmarkForPage(
      bookmark.bookId,
      bookmark.pageNumber,
    );
    if (existing == null) {
      return createBookmark(bookmark);
    }

    final merged = existing.copyWith(
      noteText: clearNoteText
          ? null
          : (bookmark.noteText ?? existing.noteText),
      clearNoteText: clearNoteText,
    );
    await updateBookmark(merged);
    return merged;
  }

  Future<int> deleteBookmark(int id) async {
    return _db.delete(
      DatabaseConfig.tableBookmarks,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteBookmarkForPage(int bookId, int pageNumber) async {
    return _db.delete(
      DatabaseConfig.tableBookmarks,
      where: 'book_id = ? AND page_number = ?',
      whereArgs: [bookId, pageNumber],
    );
  }
}
