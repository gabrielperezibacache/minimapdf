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

  Future<void> loadForBook(int bookId) async {
    _bookId = bookId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _bookmarks = await _datasource.listBookmarks(bookId);
    } catch (e) {
      _error = 'No se pudieron cargar los marcadores.';
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.loadForBook: $e');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Marca o desmarca la página actual.
  ///
  /// Si hay nota y [force] es false, no borra (el caller debe confirmar).
  /// Devuelve `false` cuando se requiere confirmación.
  Future<bool> toggleBookmark(int pageNumber, {bool force = false}) async {
    final bookId = _bookId;
    if (bookId == null || pageNumber < 1) return true;

    final existing = bookmarkForPage(pageNumber);
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
        _error = null;
        await loadForBook(bookId);
      } catch (e) {
        _error = 'No se pudo quitar el marcador.';
        if (kDebugMode) {
          debugPrint('ReaderAnnotationsProvider.toggleBookmark: $e');
        }
        notifyListeners();
      }
      return true;
    }

    try {
      await _datasource.upsertBookmark(
        Bookmark(
          bookId: bookId,
          pageNumber: pageNumber,
          createdAt: DateTime.now(),
        ),
      );
      _error = null;
      await loadForBook(bookId);
    } catch (e) {
      _error = 'No se pudo crear el marcador.';
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.toggleBookmark: $e');
      }
      notifyListeners();
    }
    return true;
  }

  /// Guarda o actualiza una nota en la página (crea marcador si no existe).
  Future<void> saveNote({
    required int pageNumber,
    required String noteText,
  }) async {
    final bookId = _bookId;
    if (bookId == null || pageNumber < 1) return;

    final trimmed = noteText.trim();
    final existing = bookmarkForPage(pageNumber);

    try {
      if (trimmed.isEmpty) {
        if (existing != null) {
          await _datasource.upsertBookmark(
            existing.copyWith(clearNoteText: true),
          );
        }
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
      _error = null;
      await loadForBook(bookId);
    } catch (e) {
      _error = 'No se pudo guardar la nota.';
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.saveNote: $e');
      }
      notifyListeners();
    }
  }

  Future<void> deleteBookmark(Bookmark bookmark) async {
    final bookId = _bookId;
    final id = bookmark.id;
    if (bookId == null || id == null) return;
    try {
      await _datasource.removeBookmark(id);
      _error = null;
      await loadForBook(bookId);
    } catch (e) {
      _error = 'No se pudo eliminar el marcador.';
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.deleteBookmark: $e');
      }
      notifyListeners();
    }
  }
}
