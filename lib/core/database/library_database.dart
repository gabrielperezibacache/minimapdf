import 'package:path/path.dart' as p;
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
    return Collection.tryFromMap(rows.first);
  }

  Future<List<Collection>> getAllCollections() async {
    final rows = await _db.query(
      DatabaseConfig.tableCollections,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    final collections = <Collection>[];
    for (final row in rows) {
      final collection = Collection.tryFromMap(row);
      if (collection != null) collections.add(collection);
    }
    return collections;
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
    return Book.tryFromMap(rows.first);
  }

  Future<Book?> getBookByFilePath(String filePath) async {
    final rows = await _db.query(
      DatabaseConfig.tableBooks,
      where: 'file_path = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.tryFromMap(rows.first);
  }

  /// Basenames reservados en DB (incluye filas huérfanas sin archivo en disco).
  Future<Set<String>> listReservedLibraryBasenames() async {
    final rows = await _db.query(
      DatabaseConfig.tableBooks,
      columns: const ['file_path'],
    );
    final names = <String>{};
    for (final row in rows) {
      final path = row['file_path'];
      if (path is! String || path.isEmpty) continue;
      names.add(p.basename(path).toLowerCase());
    }
    return names;
  }

  /// `true` si ya hay al menos un libro (p. ej. instalación previa al onboarding).
  Future<bool> hasAnyBooks() async {
    final rows = await _db.rawQuery(
      'SELECT 1 FROM ${DatabaseConfig.tableBooks} LIMIT 1',
    );
    return rows.isNotEmpty;
  }

  /// Libros de biblioteca: primero por última lectura, luego por alta.
  ///
  /// Si [limit] es null, devuelve todos (sin truncar silenciosamente).
  /// Filas corruptas se omiten para no tumbar la carga de la biblioteca.
  Future<List<Book>> getRecentBooks({int? limit}) async {
    final rows = await _db.query(
      DatabaseConfig.tableBooks,
      orderBy: 'last_read_at IS NULL, last_read_at DESC, added_at DESC',
      limit: limit,
    );
    return _parseBooks(rows);
  }

  Future<List<Book>> getAllBooks() async {
    final rows = await _db.query(
      DatabaseConfig.tableBooks,
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return _parseBooks(rows);
  }

  Future<List<Book>> getBooksByCollection(int? collectionId) async {
    if (collectionId == null) {
      final rows = await _db.query(
        DatabaseConfig.tableBooks,
        where: 'collection_id IS NULL',
        orderBy: 'title COLLATE NOCASE ASC',
      );
      return _parseBooks(rows);
    }

    final rows = await _db.query(
      DatabaseConfig.tableBooks,
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return _parseBooks(rows);
  }

  List<Book> _parseBooks(List<Map<String, Object?>> rows) {
    final books = <Book>[];
    for (final row in rows) {
      final book = Book.tryFromMap(row);
      if (book != null) books.add(book);
    }
    return books;
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
    return Bookmark.tryFromMap(rows.first);
  }

  Future<List<Bookmark>> getBookmarksForBook(int bookId) async {
    final rows = await _db.query(
      DatabaseConfig.tableBookmarks,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'page_number ASC',
    );
    final bookmarks = <Bookmark>[];
    for (final row in rows) {
      final bookmark = Bookmark.tryFromMap(row);
      if (bookmark != null) bookmarks.add(bookmark);
    }
    return bookmarks;
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
    return _db.transaction((txn) async {
      final rows = await txn.query(
        DatabaseConfig.tableBookmarks,
        where: 'book_id = ? AND page_number = ?',
        whereArgs: [bookmark.bookId, bookmark.pageNumber],
        limit: 1,
      );

      if (rows.isEmpty) {
        // No resucitar un marcador solo para borrar su nota.
        if (clearNoteText &&
            (bookmark.noteText == null || bookmark.noteText!.trim().isEmpty)) {
          return bookmark;
        }
        final id = await txn.insert(
          DatabaseConfig.tableBookmarks,
          bookmark.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        return bookmark.copyWith(id: id);
      }

      final existing = Bookmark.tryFromMap(rows.first);
      if (existing == null || existing.id == null) {
        // Fila corrupta: reemplazar.
        await txn.delete(
          DatabaseConfig.tableBookmarks,
          where: 'book_id = ? AND page_number = ?',
          whereArgs: [bookmark.bookId, bookmark.pageNumber],
        );
        final replacement = bookmark.copyWith(
          noteText: clearNoteText ? null : bookmark.noteText,
          clearNoteText: clearNoteText,
        );
        final id = await txn.insert(
          DatabaseConfig.tableBookmarks,
          replacement.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        return replacement.copyWith(id: id);
      }

      final merged = existing.copyWith(
        noteText: clearNoteText
            ? null
            : (bookmark.noteText ?? existing.noteText),
        clearNoteText: clearNoteText,
      );
      final updated = await txn.update(
        DatabaseConfig.tableBookmarks,
        merged.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      if (updated == 0) {
        final id = await txn.insert(
          DatabaseConfig.tableBookmarks,
          merged.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        return merged.copyWith(id: id);
      }
      return merged;
    });
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

  // ---------------------------------------------------------------------------
  // Document signatures (firma electrónica simple / mecanografiada)
  // ---------------------------------------------------------------------------

  Future<DocumentSignature> createSignature(DocumentSignature signature) async {
    final id = await _db.insert(
      DatabaseConfig.tableSignatures,
      signature.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return signature.copyWith(id: id);
  }

  /// Inserta la firma asignando `signing_order` atómicamente (MAX+1).
  Future<DocumentSignature> createSignatureWithNextOrder(
    DocumentSignature signature,
  ) async {
    return _db.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT MAX(signing_order) AS max_order '
        'FROM ${DatabaseConfig.tableSignatures} WHERE book_id = ?',
        [signature.bookId],
      );
      final maxOrder = rows.first['max_order'] as num?;
      final nextOrder = (maxOrder?.toInt() ?? 0) + 1;
      final ordered = signature.copyWith(signingOrder: nextOrder);
      final id = await txn.insert(
        DatabaseConfig.tableSignatures,
        ordered.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return ordered.copyWith(id: id);
    });
  }

  Future<DocumentSignature?> getSignatureById(int id) async {
    final rows = await _db.query(
      DatabaseConfig.tableSignatures,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DocumentSignature.tryFromMap(rows.first);
  }

  Future<List<DocumentSignature>> getSignaturesForBook(int bookId) async {
    final rows = await _db.query(
      DatabaseConfig.tableSignatures,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'signing_order ASC, page_number ASC, signed_at ASC',
    );
    return _parseSignatures(rows);
  }

  Future<List<DocumentSignature>> getSignaturesForPage(
    int bookId,
    int pageNumber,
  ) async {
    final rows = await _db.query(
      DatabaseConfig.tableSignatures,
      where: 'book_id = ? AND page_number = ?',
      whereArgs: [bookId, pageNumber],
      orderBy: 'signing_order ASC, signed_at ASC',
    );
    return _parseSignatures(rows);
  }

  List<DocumentSignature> _parseSignatures(List<Map<String, Object?>> rows) {
    final signatures = <DocumentSignature>[];
    for (final row in rows) {
      final signature = DocumentSignature.tryFromMap(row);
      if (signature != null) signatures.add(signature);
    }
    return signatures;
  }

  Future<int> nextSigningOrder(int bookId) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(signing_order) AS max_order '
      'FROM ${DatabaseConfig.tableSignatures} WHERE book_id = ?',
      [bookId],
    );
    final maxOrder = rows.first['max_order'] as num?;
    return (maxOrder?.toInt() ?? 0) + 1;
  }

  Future<int> updateSignature(DocumentSignature signature) async {
    final id = signature.id;
    if (id == null) {
      throw ArgumentError('DocumentSignature.id es obligatorio para actualizar');
    }
    return _db.update(
      DatabaseConfig.tableSignatures,
      signature.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSignature(int id) async {
    return _db.delete(
      DatabaseConfig.tableSignatures,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Signature templates
  // ---------------------------------------------------------------------------

  Future<SignatureTemplate> createSignatureTemplate(
    SignatureTemplate template,
  ) async {
    final id = await _db.insert(
      DatabaseConfig.tableSignatureTemplates,
      template.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return template.copyWith(id: id);
  }

  Future<List<SignatureTemplate>> getSignatureTemplates() async {
    final rows = await _db.query(
      DatabaseConfig.tableSignatureTemplates,
      orderBy: 'created_at DESC',
    );
    final templates = <SignatureTemplate>[];
    for (final row in rows) {
      final template = SignatureTemplate.tryFromMap(row);
      if (template != null) templates.add(template);
    }
    return templates;
  }

  Future<int> deleteSignatureTemplate(int id) async {
    return _db.delete(
      DatabaseConfig.tableSignatureTemplates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Page annotations (marcado, subrayado, nota, comentario)
  // ---------------------------------------------------------------------------

  Future<PageAnnotation> createPageAnnotation(PageAnnotation annotation) async {
    final id = await _db.insert(
      DatabaseConfig.tablePageAnnotations,
      annotation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return annotation.copyWith(id: id);
  }

  Future<List<PageAnnotation>> getPageAnnotationsForBook(int bookId) async {
    final rows = await _db.query(
      DatabaseConfig.tablePageAnnotations,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'page_number ASC, created_at ASC',
    );
    return _parsePageAnnotations(rows);
  }

  Future<List<PageAnnotation>> getPageAnnotationsForPage(
    int bookId,
    int pageNumber,
  ) async {
    final rows = await _db.query(
      DatabaseConfig.tablePageAnnotations,
      where: 'book_id = ? AND page_number = ?',
      whereArgs: [bookId, pageNumber],
      orderBy: 'created_at ASC',
    );
    return _parsePageAnnotations(rows);
  }

  List<PageAnnotation> _parsePageAnnotations(List<Map<String, Object?>> rows) {
    final annotations = <PageAnnotation>[];
    for (final row in rows) {
      final annotation = PageAnnotation.tryFromMap(row);
      if (annotation != null) annotations.add(annotation);
    }
    return annotations;
  }

  Future<int> updatePageAnnotation(PageAnnotation annotation) async {
    final id = annotation.id;
    if (id == null) {
      throw ArgumentError('PageAnnotation.id es obligatorio para actualizar');
    }
    return _db.update(
      DatabaseConfig.tablePageAnnotations,
      annotation.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePageAnnotation(int id) async {
    return _db.delete(
      DatabaseConfig.tablePageAnnotations,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
