import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/preferences/app_preferences.dart';
import '../../core/utils/app_paths.dart';
import '../../data/datasources/library_local_datasource.dart';
import '../../data/datasources/pdf_import_service.dart';
import '../../data/models/models.dart';
import '../../l10n/app_message_keys.dart';

/// Estado de la biblioteca: libros, colecciones e importación local.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider({
    required this.datasource,
    required this.importService,
    AppPreferences? preferences,
    Future<Directory> Function()? documentsDirectory,
  })  : _preferences = preferences,
        _documentsDirectory =
            documentsDirectory ?? AppPaths.documentsDirectory,
        _gridMode = preferences?.gridMode ?? true;

  final LibraryLocalDatasource datasource;
  final PdfImportService importService;
  final Future<Directory> Function() _documentsDirectory;
  AppPreferences? _preferences;

  List<Book> _books = const [];
  List<Collection> _collections = const [];
  int? _selectedCollectionId;
  String _searchQuery = '';
  bool _loading = false;
  bool _importing = false;
  String? _error;
  bool _gridMode;
  int _loadGeneration = 0;

  List<Book> get books => _books;
  List<Collection> get collections => _collections;
  int? get selectedCollectionId => _selectedCollectionId;
  String get searchQuery => _searchQuery;
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
    final query = _searchQuery;
    return _books.where((book) {
      if (_selectedCollectionId != null &&
          book.collectionId != _selectedCollectionId) {
        return false;
      }
      return book.matchesQuery(query);
    }).toList(growable: false);
  }

  void setSearchQuery(String value) {
    final next = value.trimLeft();
    if (_searchQuery == next) return;
    _searchQuery = next;
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    notifyListeners();
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
      _error = AppMessageKeys.libraryLoadFailed;
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
        try {
          await load();
        } catch (e) {
          // La importación ya persistió; no reportar como fallo de import.
          _error = AppMessageKeys.libraryLoadFailed;
          if (kDebugMode) {
            debugPrint('LibraryProvider.importPdf load: $e');
          }
        }
      }
      return book;
    } catch (e) {
      if (e is FormatException) {
        _error = e.message;
      } else if (e is StateError) {
        _error = e.message;
      } else {
        _error = AppMessageKeys.importPdfFailed;
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

  /// Importa un PDF abierto desde el sistema (Open with / compartir).
  Future<Book?> importExternalFile(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty || _importing) return null;

    _importing = true;
    _error = null;
    notifyListeners();

    try {
      final source = File(trimmed);
      final size = await source.exists() ? await source.length() : 0;
      final book = await importService.importPickedFile(
        PickedPdfFile(
          sourcePath: trimmed,
          displayName: displayNameForExternalPath(trimmed),
          fileSize: size,
        ),
        collectionId: _selectedCollectionId,
      );
      try {
        await load();
      } catch (e) {
        _error = AppMessageKeys.libraryLoadFailed;
        if (kDebugMode) {
          debugPrint('LibraryProvider.importExternalFile load: $e');
        }
      }
      await _deleteExternalCacheCopy(source);
      return book;
    } catch (e) {
      if (e is FormatException) {
        _error = e.message;
      } else if (e is StateError) {
        _error = e.message;
      } else {
        _error = AppMessageKeys.importPdfFailed;
      }
      if (kDebugMode) {
        debugPrint('LibraryProvider.importExternalFile: $e');
      }
      return null;
    } finally {
      _importing = false;
      notifyListeners();
    }
  }

  /// Quita el prefijo `external_<epoch>_` que añaden Android/iOS al copiar.
  @visibleForTesting
  static String displayNameForExternalPath(String path) {
    final base = p.basename(path);
    final match = RegExp(r'^external_\d+_(.+)$').firstMatch(base);
    return match?.group(1) ?? base;
  }

  Future<void> _deleteExternalCacheCopy(File source) async {
    final name = p.basename(source.path);
    if (!name.startsWith('external_')) return;
    try {
      if (await source.exists()) {
        await source.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LibraryProvider._deleteExternalCacheCopy: $e');
      }
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
      _error = AppMessageKeys.metadataSaveFailed;
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
      _error = AppMessageKeys.collectionCreateFailed;
      if (kDebugMode) {
        debugPrint('LibraryProvider.createCollection: $e');
      }
      notifyListeners();
      return null;
    }
  }

  Future<Collection?> renameCollection(
    Collection collection,
    String name,
  ) async {
    final id = collection.id;
    final trimmed = name.trim();
    if (id == null || trimmed.isEmpty) return null;

    try {
      final updated = collection.copyWith(name: trimmed);
      await datasource.saveCollection(updated);
      _error = null;
      await load();
      return updated;
    } catch (e) {
      _error = AppMessageKeys.collectionRenameFailed;
      if (kDebugMode) {
        debugPrint('LibraryProvider.renameCollection: $e');
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
      _error = AppMessageKeys.collectionDeleteFailed;
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
      try {
        await load();
      } catch (e) {
        // El borrado ya se aplicó; no reportar como fallo de delete.
        _error = AppMessageKeys.libraryLoadFailed;
        if (kDebugMode) {
          debugPrint('LibraryProvider.deleteBook load: $e');
        }
        notifyListeners();
      }
    } catch (e) {
      _error = AppMessageKeys.deletePdfFailed;
      if (kDebugMode) {
        debugPrint('LibraryProvider.deleteBook: $e');
      }
      notifyListeners();
    }
  }

  Future<void> _deleteBookFile(String filePath) async {
    if (!await _isPathInsideLibrary(filePath)) {
      if (kDebugMode) {
        debugPrint(
          'LibraryProvider._deleteBookFile: ruta fuera de library: $filePath',
        );
      }
      return;
    }

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

    // Manifiesto compañero de exportaciones firmadas (`*.firmas.json`).
    try {
      final manifestPath = '${p.withoutExtension(filePath)}.firmas.json';
      if (!await _isPathInsideLibrary(manifestPath)) return;
      final manifest = File(manifestPath);
      if (await manifest.exists()) {
        await manifest.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LibraryProvider._deleteBookFile manifest: $e');
      }
    }
  }

  /// Solo borra archivos bajo `Documents/library` (evita path traversal).
  Future<bool> _isPathInsideLibrary(String filePath) async {
    try {
      if (filePath.trim().isEmpty) return false;
      final docs = await _documentsDirectory();
      final libraryRoot = p.normalize(p.absolute(p.join(docs.path, 'library')));
      final candidate = p.normalize(p.absolute(filePath));
      return p.isWithin(libraryRoot, candidate);
    } catch (_) {
      return false;
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
