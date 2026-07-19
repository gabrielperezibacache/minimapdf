import '../../core/database/library_database.dart';
import '../models/models.dart';

/// Acceso a datos locales de la biblioteca (delegado a [LibraryDatabase]).
class LibraryLocalDatasource {
  LibraryLocalDatasource(this._db);

  final LibraryDatabase _db;

  Future<Book> insertBook(Book book) => _db.createBook(book);

  Future<Book?> findBookById(int id) => _db.getBookById(id);

  Future<Book?> findBookByPath(String path) => _db.getBookByFilePath(path);

  Future<List<Book>> listRecentBooks({int limit = 50}) =>
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

  Future<List<Bookmark>> listBookmarks(int bookId) =>
      _db.getBookmarksForBook(bookId);

  Future<int> saveBookmark(Bookmark bookmark) => _db.updateBookmark(bookmark);

  Future<int> removeBookmark(int id) => _db.deleteBookmark(id);
}
