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

  List<Bookmark> get bookmarks => _bookmarks;
  bool get loading => _loading;

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
    notifyListeners();
    try {
      _bookmarks = await _datasource.listBookmarks(bookId);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Marca o desmarca la página actual (acento bronce en UI).
  Future<void> toggleBookmark(int pageNumber) async {
    final bookId = _bookId;
    if (bookId == null || pageNumber < 1) return;

    final existing = bookmarkForPage(pageNumber);
    if (existing != null) {
      final id = existing.id;
      if (id != null) await _datasource.removeBookmark(id);
    } else {
      await _datasource.upsertBookmark(
        Bookmark(
          bookId: bookId,
          pageNumber: pageNumber,
          createdAt: DateTime.now(),
        ),
      );
    }
    await loadForBook(bookId);
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

    if (trimmed.isEmpty) {
      if (existing != null) {
        await _datasource.upsertBookmark(
          existing.copyWith(clearNoteText: true),
        );
      }
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
    await loadForBook(bookId);
  }

  Future<void> deleteBookmark(Bookmark bookmark) async {
    final bookId = _bookId;
    final id = bookmark.id;
    if (bookId == null || id == null) return;
    await _datasource.removeBookmark(id);
    await loadForBook(bookId);
  }
}
