import 'package:flutter/foundation.dart';

import '../../data/datasources/library_local_datasource.dart';
import '../../data/models/bookmark.dart';

/// Marcadores y notas locales del lector activo.
class ReaderAnnotationsProvider extends ChangeNotifier {
  ReaderAnnotationsProvider(this._datasource);

  final LibraryLocalDatasource _datasource;

  int? _bookId;
  List<Bookmark> _bookmarks = const [];
  bool _loading = false;
  String? _error;
  bool _disposed = false;
  int _loadGeneration = 0;

  List<Bookmark> get bookmarks => _bookmarks;
  bool get loading => _loading;
  String? get error => _error;

  Bookmark? bookmarkForPage(int pageNumber) {
    for (final bookmark in _bookmarks) {
      if (bookmark.pageNumber == pageNumber) return bookmark;
    }
    return null;
  }

  bool isPageBookmarked(int pageNumber) => bookmarkForPage(pageNumber) != null;

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> loadForBook(int bookId) async {
    final generation = ++_loadGeneration;
    _bookId = bookId;
    _loading = true;
    _error = null;
    _safeNotify();
    try {
      final bookmarks = await _datasource.listBookmarks(bookId);
      if (_disposed || generation != _loadGeneration) return;
      _bookmarks = bookmarks;
    } catch (e) {
      if (_disposed || generation != _loadGeneration) return;
      _error = 'No se pudieron cargar los marcadores.';
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.loadForBook: $e');
      }
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _loading = false;
        _safeNotify();
      }
    }
  }

  /// Marca o desmarca la página actual.
  ///
  /// Si hay nota y [force] es false, no borra (el caller debe confirmar).
  /// Devuelve `false` cuando se requiere confirmación.
  Future<bool> toggleBookmark(int pageNumber, {bool force = false}) async {
    final bookId = _bookId;
    if (_disposed || bookId == null || pageNumber < 1) return true;

    // Consulta DB para no pisar notas si la lista en memoria aún no cargó.
    Bookmark? existing = bookmarkForPage(pageNumber);
    existing ??= await _datasource.findBookmarkForPage(bookId, pageNumber);
    if (_disposed) return true;

    if (existing != null) {
      final hasNote =
          existing.noteText != null && existing.noteText!.trim().isNotEmpty;
      if (hasNote && !force) {
        return false;
      }
      final id = existing.id;
      if (id == null) return true;
      try {
        await _datasource.removeBookmark(id);
        if (_disposed) return true;
        _error = null;
        await loadForBook(bookId);
      } catch (e) {
        if (_disposed) return true;
        _error = 'No se pudo quitar el marcador.';
        if (kDebugMode) {
          debugPrint('ReaderAnnotationsProvider.toggleBookmark: $e');
        }
        _safeNotify();
      }
      return true;
    }

    try {
      // upsert sin clearNoteText: conserva nota si ya existía en carrera.
      await _datasource.upsertBookmark(
        Bookmark(
          bookId: bookId,
          pageNumber: pageNumber,
          createdAt: DateTime.now(),
        ),
      );
      if (_disposed) return true;
      _error = null;
      await loadForBook(bookId);
    } catch (e) {
      if (_disposed) return true;
      _error = 'No se pudo crear el marcador.';
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.toggleBookmark: $e');
      }
      _safeNotify();
    }
    return true;
  }

  /// Guarda o actualiza una nota en la página (crea marcador si no existe).
  Future<void> saveNote({
    required int pageNumber,
    required String noteText,
  }) async {
    final bookId = _bookId;
    if (_disposed || bookId == null || pageNumber < 1) return;

    final trimmed = noteText.trim();
    final existing = bookmarkForPage(pageNumber) ??
        await _datasource.findBookmarkForPage(bookId, pageNumber);
    if (_disposed) return;

    try {
      if (trimmed.isEmpty) {
        if (existing != null) {
          await _datasource.upsertBookmark(
            existing,
            clearNoteText: true,
          );
        }
        if (_disposed) return;
        _error = null;
        await loadForBook(bookId);
        return;
      }

      await _datasource.upsertBookmark(
        Bookmark(
          id: existing?.id,
          bookId: bookId,
          pageNumber: pageNumber,
          noteText: trimmed,
          createdAt: existing?.createdAt ?? DateTime.now(),
        ),
      );
      if (_disposed) return;
      _error = null;
      await loadForBook(bookId);
    } catch (e) {
      if (_disposed) return;
      _error = 'No se pudo guardar la nota.';
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.saveNote: $e');
      }
      _safeNotify();
    }
  }

  Future<void> deleteBookmark(Bookmark bookmark) async {
    final bookId = _bookId;
    final id = bookmark.id;
    if (_disposed || bookId == null || id == null) return;
    try {
      await _datasource.removeBookmark(id);
      if (_disposed) return;
      _error = null;
      await loadForBook(bookId);
    } catch (e) {
      if (_disposed) return;
      _error = 'No se pudo eliminar el marcador.';
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.deleteBookmark: $e');
      }
      _safeNotify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }
}
