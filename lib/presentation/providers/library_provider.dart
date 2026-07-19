import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/preferences/app_preferences.dart';
import '../../data/datasources/library_local_datasource.dart';
import '../../data/datasources/pdf_import_service.dart';
import '../../data/models/models.dart';

/// Estado de la biblioteca: libros, colecciones e importación local.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider({
    required this.datasource,
    required this.importService,
    AppPreferences? preferences,
  })  : _preferences = preferences,
        _gridMode = preferences?.gridMode ?? true;

  final LibraryLocalDatasource datasource;
  final PdfImportService importService;
  AppPreferences? _preferences;

  List<Book> _books = const [];
  List<Collection> _collections = const [];
  int? _selectedCollectionId;
  bool _loading = false;
  bool _importing = false;
  String? _error;
  bool _gridMode;
  int _loadGeneration = 0;

  List<Book> get books => _books;
  List<Collection> get collections => _collections;
  int? get selectedCollectionId => _selectedCollectionId;
  bool get loading => _loading;
  bool get importing => _importing;
  String? get error => _error;
  bool get gridMode => _gridMode;

  void attachPreferences(AppPreferences preferences) {
    _preferences = preferences;
    final stored = preferences.gridMode;
    if (_gridMode != stored) {
      _gridMode = stored;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  List<Book> get visibleBooks {
    if (_selectedCollectionId == null) return _books;
    return _books
        .where((book) => book.collectionId == _selectedCollectionId)
        .toList(growable: false);
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        datasource.listRecentBooks(), // todos, ordenados por lectura reciente
        datasource.listCollections(),
      ]);
      if (generation != _loadGeneration) return;
      _books = results[0] as List<Book>;
      _collections = results[1] as List<Collection>;
    } catch (e) {
      if (generation != _loadGeneration) return;
      _error = 'No se pudo cargar la biblioteca.';
      if (kDebugMode) {
        debugPrint('LibraryProvider.load: $e');
      }
    } finally {
      if (generation == _loadGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setGridMode(bool value) async {
    if (_gridMode == value) return;
    _gridMode = value;
    notifyListeners();
    await _preferences?.setGridMode(value);
  }

  void selectCollection(int? collectionId) {
    if (_selectedCollectionId == collectionId) return;
    _selectedCollectionId = collectionId;
    // Evita que un error previo oculte el empty-state de la colección.
    _error = null;
    notifyListeners();
  }

  Future<Book?> importPdf() async {
    if (_importing) return null;

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
      if (e is FormatException) {
        _error = e.message;
      } else if (e is StateError) {
        _error = e.message;
      } else {
        _error = 'No se pudo importar el PDF.';
      }
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
    int? collectionId,
    bool clearCollectionId = false,
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
      collectionId: collectionId,
      clearCollectionId: clearCollectionId,
    );

    try {
      await datasource.saveBook(updated);
      _error = null;
      await load();
    } catch (e) {
      _error = 'No se pudieron guardar los metadatos.';
      if (kDebugMode) {
        debugPrint('LibraryProvider.updateBookMetadata: $e');
      }
      notifyListeners();
    }
  }

  Future<Collection?> createCollection(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    try {
      final collection = await datasource.insertCollection(
        Collection(name: trimmed, createdAt: DateTime.now()),
      );
      _error = null;
      await load();
      return collection;
    } catch (e) {
      _error = 'No se pudo crear la colección.';
      if (kDebugMode) {
        debugPrint('LibraryProvider.createCollection: $e');
      }
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteCollection(Collection collection) async {
    final id = collection.id;
    if (id == null) return;
    try {
      await datasource.removeCollection(id);
      if (_selectedCollectionId == id) {
        _selectedCollectionId = null;
      }
      _error = null;
      await load();
    } catch (e) {
      _error = 'No se pudo eliminar la colección.';
      if (kDebugMode) {
        debugPrint('LibraryProvider.deleteCollection: $e');
      }
      notifyListeners();
    }
  }

  /// Elimina el registro y el archivo PDF del almacenamiento de la app.
  Future<void> deleteBook(Book book) async {
    final id = book.id;
    if (id == null) return;

    try {
      await datasource.removeBook(id);
      await _deleteBookFile(book.filePath);
      _error = null;
      await load();
    } catch (e) {
      _error = 'No se pudo eliminar el PDF.';
      if (kDebugMode) {
        debugPrint('LibraryProvider.deleteBook: $e');
      }
      notifyListeners();
    }
  }

  Future<void> _deleteBookFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LibraryProvider._deleteBookFile: $e');
      }
    }
  }

  /// Comprueba que el archivo del libro sigue en disco.
  Future<bool> bookFileExists(Book book) async {
    try {
      return File(book.filePath).exists();
    } catch (_) {
      return false;
    }
  }
}
