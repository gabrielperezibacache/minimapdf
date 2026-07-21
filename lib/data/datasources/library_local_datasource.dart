import '../../core/database/library_database.dart';
import '../models/models.dart';

/// Acceso a datos locales de la biblioteca (delegado a [LibraryDatabase]).
class LibraryLocalDatasource {
  LibraryLocalDatasource(this._db);

  final LibraryDatabase _db;

  Future<Book> insertBook(Book book) => _db.createBook(book);

  Future<Book?> findBookById(int id) => _db.getBookById(id);

  Future<Book?> findBookByPath(String path) => _db.getBookByFilePath(path);

  /// Nombres de archivo ya usados en DB (evita UNIQUE tras filas huérfanas).
  Future<Set<String>> listReservedLibraryBasenames() =>
      _db.listReservedLibraryBasenames();

  Future<List<Book>> listRecentBooks({int? limit}) =>
      _db.getRecentBooks(limit: limit);

  Future<List<Book>> listAllBooks() => _db.getAllBooks();

  Future<List<Book>> listBooksInCollection(int? collectionId) =>
      _db.getBooksByCollection(collectionId);

  Future<int> saveBook(Book book) => _db.updateBook(book);

  Future<int> saveReadingProgress({
    required int bookId,
    required int lastPageRead,
    DateTime? lastReadAt,
  }) {
    return _db.updateReadingProgress(
      bookId: bookId,
      lastPageRead: lastPageRead,
      lastReadAt: lastReadAt,
    );
  }

  Future<int> removeBook(int id) => _db.deleteBook(id);

  Future<Collection> insertCollection(Collection collection) =>
      _db.createCollection(collection);

  Future<Collection?> findCollectionById(int id) => _db.getCollectionById(id);

  Future<List<Collection>> listCollections() => _db.getAllCollections();

  Future<int> saveCollection(Collection collection) =>
      _db.updateCollection(collection);

  Future<int> removeCollection(int id) => _db.deleteCollection(id);

  Future<Bookmark> insertBookmark(Bookmark bookmark) =>
      _db.createBookmark(bookmark);

  Future<Bookmark?> findBookmarkForPage(int bookId, int pageNumber) =>
      _db.getBookmarkForPage(bookId, pageNumber);

  Future<List<Bookmark>> listBookmarks(int bookId) =>
      _db.getBookmarksForBook(bookId);

  Future<Bookmark> upsertBookmark(
    Bookmark bookmark, {
    bool clearNoteText = false,
  }) {
    return _db.upsertBookmark(bookmark, clearNoteText: clearNoteText);
  }

  Future<int> saveBookmark(Bookmark bookmark) => _db.updateBookmark(bookmark);

  Future<int> removeBookmark(int id) => _db.deleteBookmark(id);

  Future<int> removeBookmarkForPage(int bookId, int pageNumber) =>
      _db.deleteBookmarkForPage(bookId, pageNumber);

  /// Siempre asigna `signing_order` en transacción (evita colisiones).
  Future<DocumentSignature> insertSignature(DocumentSignature signature) =>
      _db.createSignatureWithNextOrder(signature);

  /// Inserta firma con `signing_order` calculado en la misma transacción.
  Future<DocumentSignature> insertSignatureWithNextOrder(
    DocumentSignature signature,
  ) {
    return _db.createSignatureWithNextOrder(signature);
  }

  Future<DocumentSignature?> findSignatureById(int id) =>
      _db.getSignatureById(id);

  Future<List<DocumentSignature>> listSignatures(int bookId) =>
      _db.getSignaturesForBook(bookId);

  Future<List<DocumentSignature>> listSignaturesForPage(
    int bookId,
    int pageNumber,
  ) {
    return _db.getSignaturesForPage(bookId, pageNumber);
  }

  Future<int> saveSignature(DocumentSignature signature) =>
      _db.updateSignature(signature);

  Future<int> removeSignature(int id) => _db.deleteSignature(id);

  Future<int> nextSigningOrder(int bookId) => _db.nextSigningOrder(bookId);

  Future<SignatureTemplate> insertSignatureTemplate(
    SignatureTemplate template,
  ) {
    return _db.createSignatureTemplate(template);
  }

  Future<List<SignatureTemplate>> listSignatureTemplates() =>
      _db.getSignatureTemplates();

  Future<int> removeSignatureTemplate(int id) =>
      _db.deleteSignatureTemplate(id);

  Future<PageAnnotation> insertPageAnnotation(PageAnnotation annotation) =>
      _db.createPageAnnotation(annotation);

  Future<List<PageAnnotation>> listPageAnnotations(int bookId) =>
      _db.getPageAnnotationsForBook(bookId);

  Future<List<PageAnnotation>> listPageAnnotationsForPage(
    int bookId,
    int pageNumber,
  ) {
    return _db.getPageAnnotationsForPage(bookId, pageNumber);
  }

  Future<int> savePageAnnotation(PageAnnotation annotation) =>
      _db.updatePageAnnotation(annotation);

  Future<int> removePageAnnotation(int id) => _db.deletePageAnnotation(id);

  Future<int> removePageAnnotationsForBook(int bookId) =>
      _db.deletePageAnnotationsForBook(bookId);
}
