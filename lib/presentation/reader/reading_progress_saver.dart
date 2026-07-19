import '../../data/datasources/library_local_datasource.dart';

/// Persiste la página actual del lector en la base local.
class ReadingProgressSaver {
  ReadingProgressSaver(this._datasource);

  final LibraryLocalDatasource _datasource;
  int? _bookId;
  int _page = 1;
  bool _dirty = false;
  bool _saving = false;

  void attach({required int bookId, required int initialPage}) {
    _bookId = bookId;
    _page = initialPage < 1 ? 1 : initialPage;
    _dirty = false;
  }

  void onPageChanged(int page) {
    if (page < 1 || page == _page) return;
    _page = page;
    _dirty = true;
  }

  int get currentPage => _page;

  /// Guarda si hay cambios pendientes (cerrar / pausar app).
  Future<void> saveIfNeeded() async {
    final bookId = _bookId;
    if (!_dirty || bookId == null || _saving) return;

    _saving = true;
    try {
      await _datasource.saveReadingProgress(
        bookId: bookId,
        lastPageRead: _page,
        lastReadAt: DateTime.now(),
      );
      _dirty = false;
    } finally {
      _saving = false;
    }
  }

  /// Marca progreso y guarda de inmediato (p. ej. al salir).
  Future<void> saveNow({int? page}) async {
    if (page != null && page >= 1) {
      _page = page;
      _dirty = true;
    } else {
      _dirty = true;
    }
    await saveIfNeeded();
  }
}
