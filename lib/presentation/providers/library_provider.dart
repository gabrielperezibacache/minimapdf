import 'package:flutter/foundation.dart';

import '../../data/datasources/library_local_datasource.dart';
import '../../data/datasources/pdf_import_service.dart';
import '../../data/models/models.dart';
import '../../l10n/app_message_keys.dart';

/// Estado de la biblioteca: libros, colecciones e importación local.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider({
    required this.datasource,
    required this.importService,
  });

  final LibraryLocalDatasource datasource;
  final PdfImportService importService;

  List<Book> _books = const [];
  List<Collection> _collections = const [];
  int? _selectedCollectionId;
  bool _loading = false;
  bool _importing = false;
  String? _error;
  bool _gridMode = true;

  List<Book> get books => _books;
  List<Collection> get collections => _collections;
  int? get selectedCollectionId => _selectedCollectionId;
  bool get loading => _loading;
  bool get importing => _importing;
  String? get error => _error;
  bool get gridMode => _gridMode;

  List<Book> get visibleBooks {
    if (_selectedCollectionId == null) return _books;
    return _books
        .where((book) => book.collectionId == _selectedCollectionId)
        .toList(growable: false);
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        datasource.listRecentBooks(limit: 200),
        datasource.listCollections(),
      ]);
      _books = results[0] as List<Book>;
      _collections = results[1] as List<Collection>;
    } catch (e) {
      _error = AppMessageKeys.libraryLoadFailed;
      if (kDebugMode) {
        debugPrint('LibraryProvider.load: $e');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setGridMode(bool value) {
    if (_gridMode == value) return;
    _gridMode = value;
    notifyListeners();
  }

  void selectCollection(int? collectionId) {
    if (_selectedCollectionId == collectionId) return;
    _selectedCollectionId = collectionId;
    notifyListeners();
  }

  Future<Book?> importPdf() async {
    _importing = true;
    _error = null;
    notifyListeners();

    try {
      final book = await importService.importFromDevice(
        collectionId: _selectedCollectionId,
      );
      if (book != null) {
        await load();
      }
      return book;
    } catch (e) {
      _error = AppMessageKeys.importPdfFailed;
      if (kDebugMode) {
        debugPrint('LibraryProvider.importPdf: $e');
      }
      return null;
    } finally {
      _importing = false;
      notifyListeners();
    }
  }

  Future<void> updateBookMetadata({
    required Book book,
    required String title,
    String? author,
    required List<String> tags,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty || book.id == null) return;

    final trimmedAuthor = author?.trim();
    final clearAuthor = trimmedAuthor == null || trimmedAuthor.isEmpty;

    final updated = book.copyWith(
      title: trimmedTitle,
      author: clearAuthor ? null : trimmedAuthor,
      tags: tags,
      clearAuthor: clearAuthor,
    );

    await datasource.saveBook(updated);
    await load();
  }

  Future<Collection?> createCollection(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final collection = await datasource.insertCollection(
      Collection(name: trimmed, createdAt: DateTime.now()),
    );
    await load();
    return collection;
  }

  Future<void> deleteBook(Book book) async {
    final id = book.id;
    if (id == null) return;
    await datasource.removeBook(id);
    await load();
  }
}
