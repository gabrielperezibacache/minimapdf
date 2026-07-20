import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../../data/datasources/library_local_datasource.dart';
import '../../data/models/bookmark.dart';
import '../../data/models/page_annotation.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_message_keys.dart';

/// Herramienta activa en la caja de anotaciones del lector.
enum AnnotationTool {
  none,
  highlight,
  underline,
  note,
  comment,
  annotation;

  AnnotationType? get annotationType => switch (this) {
        AnnotationTool.none => null,
        AnnotationTool.highlight => AnnotationType.highlight,
        AnnotationTool.underline => AnnotationType.underline,
        AnnotationTool.note => AnnotationType.note,
        AnnotationTool.comment => AnnotationType.comment,
        AnnotationTool.annotation => AnnotationType.annotation,
      };

  String label(AppLocalizations l10n) => switch (this) {
        AnnotationTool.none => l10n.annotationToolNone,
        AnnotationTool.highlight => l10n.annotationHighlight,
        AnnotationTool.underline => l10n.annotationUnderline,
        AnnotationTool.note => l10n.annotationNote,
        AnnotationTool.comment => l10n.annotationComment,
        AnnotationTool.annotation => l10n.annotationGeneric,
      };

  String get labelEs => switch (this) {
        AnnotationTool.none => 'Ninguna',
        AnnotationTool.highlight => 'Marcado',
        AnnotationTool.underline => 'Subrayado',
        AnnotationTool.note => 'Nota',
        AnnotationTool.comment => 'Comentario',
        AnnotationTool.annotation => 'Anotación',
      };

  bool get needsText =>
      this == AnnotationTool.note ||
      this == AnnotationTool.comment ||
      this == AnnotationTool.annotation;

  bool get isMarkup =>
      this == AnnotationTool.highlight || this == AnnotationTool.underline;
}

/// Marcadores, notas y anotaciones espaciales del lector activo.
class ReaderAnnotationsProvider extends ChangeNotifier {
  ReaderAnnotationsProvider(this._datasource);

  final LibraryLocalDatasource _datasource;

  int? _bookId;
  List<Bookmark> _bookmarks = const [];
  List<PageAnnotation> _annotations = const [];
  AnnotationTool _activeTool = AnnotationTool.none;
  bool _toolboxVisible = false;
  bool _loading = false;
  int? _loadingGeneration;
  String? _error;
  bool _disposed = false;
  int _loadGeneration = 0;
  Future<void>? _mutation;

  List<Bookmark> get bookmarks => _bookmarks;
  List<PageAnnotation> get annotations => _annotations;
  AnnotationTool get activeTool => _activeTool;
  bool get toolboxVisible => _toolboxVisible;
  bool get loading => _loading;
  String? get error => _error;
  bool get isDrawingToolActive => _activeTool != AnnotationTool.none;

  Bookmark? bookmarkForPage(int pageNumber) {
    for (final bookmark in _bookmarks) {
      if (bookmark.pageNumber == pageNumber) return bookmark;
    }
    return null;
  }

  bool isPageBookmarked(int pageNumber) => bookmarkForPage(pageNumber) != null;

  List<PageAnnotation> annotationsForPage(int pageNumber) {
    return _annotations
        .where((annotation) => annotation.pageNumber == pageNumber)
        .toList(growable: false);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Serializa mutaciones; no inicia trabajo nuevo tras [dispose].
  Future<void> _enqueue(Future<void> Function() action) async {
    while (_mutation != null) {
      try {
        await _mutation;
      } catch (_) {
        // Continúa con la siguiente operación en cola.
      }
      if (_disposed) return;
    }
    if (_disposed) return;

    final completer = Completer<void>();
    _mutation = completer.future;
    try {
      await action();
    } finally {
      if (identical(_mutation, completer.future)) {
        _mutation = null;
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> loadForBook(int bookId) async {
    final generation = ++_loadGeneration;
    _bookId = bookId;
    _loadingGeneration = generation;
    _loading = true;
    _error = null;
    _safeNotify();
    try {
      final bookmarks = await _datasource.listBookmarks(bookId);
      final annotations = await _datasource.listPageAnnotations(bookId);
      if (_disposed || generation != _loadGeneration) return;
      _bookmarks = bookmarks;
      _annotations = annotations;
    } catch (e) {
      if (_disposed || generation != _loadGeneration) return;
      _error = AppMessageKeys.annotationsLoadFailed;
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.loadForBook: $e');
      }
    } finally {
      // Limpia loading aunque un refresh haya invalidado la generación de datos.
      if (!_disposed && _loadingGeneration == generation) {
        _loading = false;
        _safeNotify();
      }
    }
  }

  /// Recarga tras mutación exitosa sin reportar fallo de reload como error
  /// de guardado (la UI no debe mostrar "no se pudo guardar" si ya persistió).
  Future<void> _refreshAfterMutation(int bookId) async {
    final generation = ++_loadGeneration;
    try {
      final bookmarks = await _datasource.listBookmarks(bookId);
      final annotations = await _datasource.listPageAnnotations(bookId);
      if (_disposed || generation != _loadGeneration) return;
      _bookmarks = bookmarks;
      _annotations = annotations;
      _safeNotify();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider._refreshAfterMutation: $e');
      }
    }
  }

  void toggleToolbox() {
    if (_disposed) return;
    _toolboxVisible = !_toolboxVisible;
    if (!_toolboxVisible) {
      _activeTool = AnnotationTool.none;
    }
    // No auto-selecciona herramienta: el scroll del PDF debe seguir libre
    // hasta que el usuario elija Marcado/Subrayado/Nota conscientemente.
    _safeNotify();
  }

  void setToolboxVisible(bool visible) {
    if (_disposed) return;
    if (!visible) {
      if (!_toolboxVisible && _activeTool == AnnotationTool.none) return;
      _toolboxVisible = false;
      _activeTool = AnnotationTool.none;
      _safeNotify();
      return;
    }

    final alreadyOpen = _toolboxVisible;
    _toolboxVisible = true;
    if (!alreadyOpen) _safeNotify();
  }

  void selectTool(AnnotationTool tool) {
    if (_disposed) return;
    _activeTool = _activeTool == tool ? AnnotationTool.none : tool;
    if (_activeTool != AnnotationTool.none) {
      _toolboxVisible = true;
    }
    _safeNotify();
  }

  void clearTool() {
    if (_disposed || _activeTool == AnnotationTool.none) return;
    _activeTool = AnnotationTool.none;
    _safeNotify();
  }

  /// Marca o desmarca la página actual.
  ///
  /// Si hay nota y [force] es false, no borra (el caller debe confirmar).
  /// Devuelve `false` cuando se requiere confirmación.
  Future<bool> toggleBookmark(int pageNumber, {bool force = false}) async {
    var result = true;
    await _enqueue(() async {
      result = await _toggleBookmarkBody(pageNumber, force: force);
    });
    return result;
  }

  Future<bool> _toggleBookmarkBody(int pageNumber, {bool force = false}) async {
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
        await _refreshAfterMutation(bookId);
      } catch (e) {
        if (_disposed) return true;
        _error = AppMessageKeys.bookmarkRemoveFailed;
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
      await _refreshAfterMutation(bookId);
    } catch (e) {
      if (_disposed) return true;
      _error = AppMessageKeys.bookmarkCreateFailed;
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
    await _enqueue(
      () => _saveNoteBody(pageNumber: pageNumber, noteText: noteText),
    );
  }

  Future<void> _saveNoteBody({
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
        await _refreshAfterMutation(bookId);
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
      await _refreshAfterMutation(bookId);
    } catch (e) {
      if (_disposed) return;
      _error = AppMessageKeys.noteSaveFailed;
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.saveNote: $e');
      }
      _safeNotify();
    }
  }

  Future<void> deleteBookmark(Bookmark bookmark) async {
    await _enqueue(() => _deleteBookmarkBody(bookmark));
  }

  Future<void> _deleteBookmarkBody(Bookmark bookmark) async {
    final bookId = _bookId;
    final id = bookmark.id;
    if (_disposed || bookId == null || id == null) return;
    try {
      await _datasource.removeBookmark(id);
      if (_disposed) return;
      _error = null;
      await _refreshAfterMutation(bookId);
    } catch (e) {
      if (_disposed) return;
      _error = AppMessageKeys.bookmarkDeleteFailed;
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.deleteBookmark: $e');
      }
      _safeNotify();
    }
  }

  Future<PageAnnotation?> addAnnotation({
    required int pageNumber,
    required AnnotationType type,
    required double x,
    required double y,
    required double width,
    required double height,
    String? text,
  }) async {
    PageAnnotation? created;
    await _enqueue(() async {
      created = await _addAnnotationBody(
        pageNumber: pageNumber,
        type: type,
        x: x,
        y: y,
        width: width,
        height: height,
        text: text,
      );
    });
    return created;
  }

  Future<PageAnnotation?> _addAnnotationBody({
    required int pageNumber,
    required AnnotationType type,
    required double x,
    required double y,
    required double width,
    required double height,
    String? text,
  }) async {
    final bookId = _bookId;
    if (_disposed || bookId == null || pageNumber < 1) return null;

    final clamped = _clampRect(x: x, y: y, width: width, height: height);
    if (clamped == null) {
      _error = AppMessageKeys.annotationGeometryInvalid;
      _safeNotify();
      return null;
    }
    try {
      final created = await _datasource.insertPageAnnotation(
        PageAnnotation(
          bookId: bookId,
          pageNumber: pageNumber,
          type: type,
          text: text?.trim().isEmpty == true ? null : text?.trim(),
          x: clamped.$1,
          y: clamped.$2,
          width: clamped.$3,
          height: clamped.$4,
          colorValue: _colorToArgb(type.defaultColor),
          createdAt: DateTime.now(),
        ),
      );
      if (_disposed) return null;
      _error = null;
      // Actualización optimista: la UI ve el alta aunque falle el reload.
      _annotations = [
        for (final item in _annotations)
          if (item.id != created.id) item,
        created,
      ];
      _safeNotify();
      await _refreshAfterMutation(bookId);
      return created;
    } catch (e) {
      if (_disposed) return null;
      _error = AppMessageKeys.annotationSaveFailed;
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.addAnnotation: $e');
      }
      _safeNotify();
      return null;
    }
  }

  Future<void> updateAnnotationText({
    required PageAnnotation annotation,
    required String text,
  }) async {
    await _enqueue(
      () => _updateAnnotationTextBody(annotation: annotation, text: text),
    );
  }

  Future<void> _updateAnnotationTextBody({
    required PageAnnotation annotation,
    required String text,
  }) async {
    final bookId = _bookId;
    final id = annotation.id;
    if (_disposed || bookId == null || id == null) return;

    final trimmed = text.trim();
    try {
      final updated = annotation.copyWith(
        text: trimmed,
        clearText: trimmed.isEmpty,
      );
      await _datasource.savePageAnnotation(updated);
      if (_disposed) return;
      _error = null;
      _annotations = [
        for (final item in _annotations)
          if (item.id == id) updated else item,
      ];
      _safeNotify();
      await _refreshAfterMutation(bookId);
    } catch (e) {
      if (_disposed) return;
      _error = AppMessageKeys.annotationUpdateFailed;
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.updateAnnotationText: $e');
      }
      _safeNotify();
    }
  }

  Future<void> deleteAnnotation(PageAnnotation annotation) async {
    await _enqueue(() => _deleteAnnotationBody(annotation));
  }

  Future<void> _deleteAnnotationBody(PageAnnotation annotation) async {
    final bookId = _bookId;
    final id = annotation.id;
    if (_disposed || bookId == null || id == null) return;
    try {
      await _datasource.removePageAnnotation(id);
      if (_disposed) return;
      _error = null;
      _annotations = [
        for (final item in _annotations)
          if (item.id != id) item,
      ];
      _safeNotify();
      await _refreshAfterMutation(bookId);
    } catch (e) {
      if (_disposed) return;
      _error = AppMessageKeys.annotationDeleteFailed;
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.deleteAnnotation: $e');
      }
      _safeNotify();
    }
  }

  (double, double, double, double)? _clampRect({
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    if (!x.isFinite || !y.isFinite || !width.isFinite || !height.isFinite) {
      return null;
    }
    var left = x.clamp(0.0, 1.0);
    var top = y.clamp(0.0, 1.0);
    var w = width.clamp(0.02, 1.0);
    var h = height.clamp(0.01, 1.0);
    if (left + w > 1) left = 1 - w;
    if (top + h > 1) top = 1 - h;
    return (left, top, w, h);
  }

  static int _colorToArgb(Color color) {
    return (color.a * 255).round() << 24 |
        (color.r * 255).round() << 16 |
        (color.g * 255).round() << 8 |
        (color.b * 255).round();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }
}
