import 'dart:async';

import '../../data/datasources/library_local_datasource.dart';

/// Persiste la página actual del lector en la base local.
///
/// Evita perder progreso si hay un guardado en vuelo y la página cambia.
/// Además programa un autosave diferido al cambiar de página.
class ReadingProgressSaver {
  ReadingProgressSaver(
    this._datasource, {
    this._autosaveDelay = const Duration(seconds: 2),
  });

  final LibraryLocalDatasource _datasource;
  final Duration _autosaveDelay;

  int? _bookId;
  int _page = 1;
  bool _dirty = false;
  Future<void>? _inFlight;
  Timer? _autosaveTimer;

  void attach({required int bookId, required int initialPage}) {
    _bookId = bookId;
    _page = initialPage < 1 ? 1 : initialPage;
    _dirty = false;
    _autosaveTimer?.cancel();
  }

  void onPageChanged(int page) {
    if (page < 1 || page == _page) return;
    _page = page;
    _dirty = true;
    _scheduleAutosave();
  }

  int get currentPage => _page;
  bool get isDirty => _dirty;

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, () {
      unawaited(saveIfNeeded());
    });
  }

  /// Guarda si hay cambios pendientes (cerrar / pausar app).
  Future<void> saveIfNeeded() async {
    while (true) {
      final bookId = _bookId;
      if (!_dirty || bookId == null) return;

      final pending = _inFlight;
      if (pending != null) {
        await pending;
        continue;
      }

      final pageToSave = _page;
      final completer = Completer<void>();
      _inFlight = completer.future;
      try {
        await _datasource.saveReadingProgress(
          bookId: bookId,
          lastPageRead: pageToSave,
          lastReadAt: DateTime.now(),
        );
        // Solo limpia dirty si la página no cambió durante el await.
        if (_page == pageToSave) {
          _dirty = false;
        }
      } finally {
        _inFlight = null;
        completer.complete();
      }
    }
  }

  /// Marca progreso y guarda de inmediato (p. ej. al salir).
  Future<void> saveNow({int? page}) async {
    _autosaveTimer?.cancel();
    if (page != null && page >= 1) {
      if (page != _page) {
        _page = page;
      }
      _dirty = true;
    } else if (_bookId != null) {
      _dirty = true;
    }
    await saveIfNeeded();
  }

  void dispose() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
  }
}
