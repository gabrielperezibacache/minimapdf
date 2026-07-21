import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../../core/utils/library_file_coordinator.dart';
import '../../data/datasources/library_local_datasource.dart';
import '../../data/models/book.dart';
import '../../data/models/bookmark.dart';
import '../../data/models/page_annotation.dart';
import '../../domain/annotated_pdf_export_service.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_message_keys.dart';
import '../reader/annotation_ink.dart';

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

enum _AnnotationHistoryKind { created, deleted }

class _AnnotationHistoryEntry {
  const _AnnotationHistoryEntry({
    required this.kind,
    required this.snapshot,
  });

  final _AnnotationHistoryKind kind;
  final PageAnnotation snapshot;
}

/// Marcadores, notas y anotaciones espaciales del lector activo.
class ReaderAnnotationsProvider extends ChangeNotifier {
  ReaderAnnotationsProvider(
    this._datasource, {
    AnnotatedPdfExportService? exportService,
  }) : _exportService = exportService ?? AnnotatedPdfExportService();

  final LibraryLocalDatasource _datasource;
  final AnnotatedPdfExportService _exportService;

  static const int _maxHistory = 40;

  int? _bookId;
  List<Bookmark> _bookmarks = const [];
  List<PageAnnotation> _annotations = const [];
  AnnotationTool _activeTool = AnnotationTool.none;
  bool _toolboxVisible = false;
  /// Con herramienta armada: si true, bloquea scroll del PdfView y zoom PhotoView.
  bool _navigationLocked = true;
  bool _loading = false;
  int? _loadingGeneration;
  String? _error;
  bool _disposed = false;
  int _loadGeneration = 0;
  Future<void>? _mutation;

  Color _inkColor = MarkupInkStyle.palette[1]; // bronce
  int _strokeSizeIndex = 2;
  final List<_AnnotationHistoryEntry> _undoStack = [];
  final List<_AnnotationHistoryEntry> _redoStack = [];
  bool _savingToPdf = false;

  List<Bookmark> get bookmarks => _bookmarks;
  List<PageAnnotation> get annotations => _annotations;
  AnnotationTool get activeTool => _activeTool;
  bool get toolboxVisible => _toolboxVisible;
  bool get loading => _loading;
  String? get error => _error;
  bool get isDrawingToolActive => _activeTool != AnnotationTool.none;
  bool get savingToPdf => _savingToPdf;
  bool get hasAnnotations => _annotations.isNotEmpty;
  /// Candado cerrado: sin scroll/zoom con la herramienta armada.
  /// Candado abierto: se puede desplazar y hacer zoom (dos dedos).
  bool get navigationLocked => _navigationLocked;

  Color get inkColor => _inkColor;
  int get strokeSizeIndex => _strokeSizeIndex;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Grosor actual en px según herramienta (o default de marcado).
  double get activeStrokeWidthPx {
    final tool = _activeTool.isMarkup ? _activeTool : AnnotationTool.highlight;
    return MarkupInkStyle.widthFor(tool: tool, sizeIndex: _strokeSizeIndex);
  }

  /// Color listo para pintar el borrador / guardar.
  Color get activeInkColor {
    final tool = _activeTool.isMarkup ? _activeTool : AnnotationTool.highlight;
    return MarkupInkStyle.resolveColor(_inkColor, tool);
  }

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

  void _clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  void _pushHistory(_AnnotationHistoryEntry entry) {
    _undoStack.add(entry);
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
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
    _clearHistory();
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

  /// Oculta el panel pero mantiene la herramienta (barra compacta en el lector).
  void minimizeToolbox() {
    if (_disposed || !_toolboxVisible) return;
    _toolboxVisible = false;
    _safeNotify();
  }

  void selectTool(AnnotationTool tool) {
    if (_disposed) return;
    _activeTool = _activeTool == tool ? AnnotationTool.none : tool;
    if (_activeTool != AnnotationTool.none) {
      _toolboxVisible = true;
      if (_activeTool.isMarkup) {
        _strokeSizeIndex =
            _strokeSizeIndex.clamp(0, MarkupInkStyle.sizeCount - 1);
      }
    }
    _safeNotify();
  }

  void clearTool() {
    if (_disposed || _activeTool == AnnotationTool.none) return;
    _activeTool = AnnotationTool.none;
    _safeNotify();
  }

  void toggleNavigationLock() {
    if (_disposed) return;
    _navigationLocked = !_navigationLocked;
    _safeNotify();
  }

  void setNavigationLocked(bool locked) {
    if (_disposed) return;
    if (_navigationLocked == locked) return;
    _navigationLocked = locked;
    _safeNotify();
  }

  void setInkColor(Color color) {
    if (_disposed) return;
    if (_inkColor.toARGB32() == color.toARGB32()) return;
    _inkColor = color;
    _safeNotify();
  }

  void setStrokeSizeIndex(int index) {
    if (_disposed) return;
    final next = index.clamp(0, MarkupInkStyle.sizeCount - 1);
    if (next == _strokeSizeIndex) return;
    _strokeSizeIndex = next;
    _safeNotify();
  }

  Future<bool> undo() async {
    if (!canUndo) return false;
    var ok = false;
    await _enqueue(() async {
      ok = await _undoBody();
    });
    return ok;
  }

  Future<bool> redo() async {
    if (!canRedo) return false;
    var ok = false;
    await _enqueue(() async {
      ok = await _redoBody();
    });
    return ok;
  }

  Future<bool> _undoBody() async {
    final bookId = _bookId;
    if (_disposed || bookId == null || _undoStack.isEmpty) return false;
    final entry = _undoStack.removeLast();
    try {
      switch (entry.kind) {
        case _AnnotationHistoryKind.created:
          final id = entry.snapshot.id;
          if (id == null) {
            _undoStack.add(entry);
            return false;
          }
          await _datasource.removePageAnnotation(id);
          if (_disposed) return false;
          _annotations = [
            for (final item in _annotations)
              if (item.id != id) item,
          ];
          _redoStack.add(entry);
          _error = null;
          _safeNotify();
          await _refreshAfterMutation(bookId);
          return true;
        case _AnnotationHistoryKind.deleted:
          final restored = await _datasource.insertPageAnnotation(
            entry.snapshot.copyWith(clearId: true),
          );
          if (_disposed) return false;
          _annotations = [
            for (final item in _annotations)
              if (item.id != restored.id) item,
            restored,
          ];
          _redoStack.add(
            _AnnotationHistoryEntry(
              kind: _AnnotationHistoryKind.deleted,
              snapshot: restored,
            ),
          );
          _error = null;
          _safeNotify();
          await _refreshAfterMutation(bookId);
          return true;
      }
    } catch (e) {
      _undoStack.add(entry);
      if (_disposed) return false;
      _error = AppMessageKeys.annotationUpdateFailed;
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.undo: $e');
      }
      _safeNotify();
      return false;
    }
  }

  Future<bool> _redoBody() async {
    final bookId = _bookId;
    if (_disposed || bookId == null || _redoStack.isEmpty) return false;
    final entry = _redoStack.removeLast();
    try {
      switch (entry.kind) {
        case _AnnotationHistoryKind.created:
          final restored = await _datasource.insertPageAnnotation(
            entry.snapshot.copyWith(clearId: true),
          );
          if (_disposed) return false;
          _annotations = [
            for (final item in _annotations)
              if (item.id != restored.id) item,
            restored,
          ];
          _undoStack.add(
            _AnnotationHistoryEntry(
              kind: _AnnotationHistoryKind.created,
              snapshot: restored,
            ),
          );
          _error = null;
          _safeNotify();
          await _refreshAfterMutation(bookId);
          return true;
        case _AnnotationHistoryKind.deleted:
          final id = entry.snapshot.id;
          if (id == null) {
            _redoStack.add(entry);
            return false;
          }
          await _datasource.removePageAnnotation(id);
          if (_disposed) return false;
          _annotations = [
            for (final item in _annotations)
              if (item.id != id) item,
          ];
          _undoStack.add(entry);
          _error = null;
          _safeNotify();
          await _refreshAfterMutation(bookId);
          return true;
      }
    } catch (e) {
      _redoStack.add(entry);
      if (_disposed) return false;
      _error = AppMessageKeys.annotationUpdateFailed;
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.redo: $e');
      }
      _safeNotify();
      return false;
    }
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
    List<List<List<double>>>? strokes,
    Color? color,
    double? strokeWidth,
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
        strokes: strokes,
        color: color,
        strokeWidth: strokeWidth,
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
    List<List<List<double>>>? strokes,
    Color? color,
    double? strokeWidth,
  }) async {
    final bookId = _bookId;
    if (_disposed || bookId == null || pageNumber < 1) return null;

    final clamped = _clampRect(x: x, y: y, width: width, height: height);
    if (clamped == null) {
      _error = AppMessageKeys.annotationGeometryInvalid;
      _safeNotify();
      return null;
    }
    String? inkJson;
    if (strokes != null && strokes.isNotEmpty) {
      final valid = strokes
          .where((stroke) => stroke.length >= 2)
          .toList(growable: false);
      if (valid.isNotEmpty) {
        inkJson = jsonEncode(valid);
      }
    }

    final tool = switch (type) {
      AnnotationType.highlight => AnnotationTool.highlight,
      AnnotationType.underline => AnnotationTool.underline,
      AnnotationType.note => AnnotationTool.note,
      AnnotationType.comment => AnnotationTool.comment,
      AnnotationType.annotation => AnnotationTool.annotation,
    };
    final resolvedColor = color ??
        (type.isMarkup
            ? MarkupInkStyle.resolveColor(_inkColor, tool)
            : type.defaultColor);
    final resolvedWidth = strokeWidth ??
        (type.isMarkup
            ? MarkupInkStyle.widthFor(
                tool: tool,
                sizeIndex: _strokeSizeIndex,
              )
            : null);

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
          inkJson: inkJson,
          strokeWidth: resolvedWidth,
          colorValue: _colorToArgb(resolvedColor),
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
      _pushHistory(
        _AnnotationHistoryEntry(
          kind: _AnnotationHistoryKind.created,
          snapshot: created,
        ),
      );
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
      _pushHistory(
        _AnnotationHistoryEntry(
          kind: _AnnotationHistoryKind.deleted,
          snapshot: annotation,
        ),
      );
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

  /// Aplana las anotaciones en el PDF: copia en biblioteca o sobrescribe.
  ///
  /// Para [AnnotatedPdfSaveTarget.currentDocument], [prepareOverwrite] debe
  /// cerrar el PdfDocument abierto antes de escribir el archivo.
  Future<AnnotatedPdfExportResult?> saveAnnotationsToPdf({
    required Book book,
    required AnnotatedPdfSaveTarget target,
    Future<void> Function()? prepareOverwrite,
    String annotatedMarker = 'annotated',
  }) async {
    AnnotatedPdfExportResult? result;
    await _enqueue(() async {
      result = await _saveAnnotationsToPdfBody(
        book: book,
        target: target,
        prepareOverwrite: prepareOverwrite,
        annotatedMarker: annotatedMarker,
      );
    });
    return result;
  }

  Future<AnnotatedPdfExportResult?> _saveAnnotationsToPdfBody({
    required Book book,
    required AnnotatedPdfSaveTarget target,
    Future<void> Function()? prepareOverwrite,
    required String annotatedMarker,
  }) async {
    if (_disposed) return null;
    if (_annotations.isEmpty) {
      _error = AppMessageKeys.needAnnotations;
      _safeNotify();
      return null;
    }
    if (_savingToPdf) {
      _error = AppMessageKeys.exportInProgress;
      _safeNotify();
      return null;
    }

    _savingToPdf = true;
    _error = null;
    _safeNotify();

    final snapshot = List<PageAnnotation>.from(_annotations);
    AnnotatedPdfExportResult? written;
    try {
      final result = await LibraryFileCoordinator.runExclusive(() async {
        switch (target) {
          case AnnotatedPdfSaveTarget.libraryCopy:
            final reserved =
                await _datasource.listReservedLibraryBasenames();
            final marker = annotatedMarker.trim().isEmpty
                ? 'annotated'
                : annotatedMarker.trim();
            final exported = await _exportService.exportAsLibraryCopy(
              book: book,
              annotations: snapshot,
              reservedBasenames: reserved,
              marker: marker,
            );
            written = exported;

            var collectionId = book.collectionId;
            if (collectionId != null) {
              final found =
                  await _datasource.findCollectionById(collectionId);
              collectionId = found?.id;
            }

            final baseTitle = book.title
                .replaceAll(RegExp(r'\s*\(annotated\)\s*$', caseSensitive: false), '')
                .trim();
            final tags = {
              for (final tag in book.tags) tag,
              marker,
            }.toList(growable: false);

            await _datasource.insertBook(
              Book(
                title: '$baseTitle ($marker)',
                filePath: exported.pdfPath,
                fileSize: await File(exported.pdfPath).length(),
                addedAt: DateTime.now(),
                collectionId: collectionId,
                author: book.author,
                tags: tags,
              ),
            );
            return exported;

          case AnnotatedPdfSaveTarget.currentDocument:
            if (prepareOverwrite != null) {
              await prepareOverwrite();
            }
            final exported = await _exportService.overwriteCurrentDocument(
              book: book,
              annotations: snapshot,
            );
            written = exported;

            final bookId = book.id;
            if (bookId != null) {
              final size = await File(exported.pdfPath).length();
              await _datasource.saveBook(book.copyWith(fileSize: size));
              await _datasource.removePageAnnotationsForBook(bookId);
            }
            return exported;
        }
      });

      if (_disposed) return result;
      written = null;
      if (target == AnnotatedPdfSaveTarget.currentDocument) {
        _annotations = const [];
        _clearHistory();
      }
      _error = null;
      _safeNotify();
      return result;
    } catch (e) {
      final orphan = written;
      if (orphan != null &&
          orphan.target == AnnotatedPdfSaveTarget.libraryCopy) {
        try {
          final file = File(orphan.pdfPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      if (_disposed) return null;
      _error = AppMessageKeys.exportAnnotatedFailed;
      if (kDebugMode) {
        debugPrint('ReaderAnnotationsProvider.saveAnnotationsToPdf: $e');
      }
      _safeNotify();
      return null;
    } finally {
      if (!_disposed) {
        _savingToPdf = false;
        _safeNotify();
      }
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
    var w = width.clamp(0.01, 1.0);
    var h = height.clamp(0.006, 1.0);
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

  void clearError() {
    if (_error == null) return;
    _error = null;
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _clearHistory();
    super.dispose();
  }
}
