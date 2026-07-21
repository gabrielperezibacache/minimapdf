import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/preferences/app_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/ebony_pdf_filter.dart';
import '../../data/datasources/library_local_datasource.dart';
import '../../data/models/book.dart';
import '../../data/models/bookmark.dart';
import '../../data/models/document_signature.dart';
import '../../data/models/page_annotation.dart';
import '../../data/models/signature_role.dart';
import '../../domain/annotated_pdf_export_service.dart';
import '../../l10n/app_localizations.dart';
import '../providers/document_signing_provider.dart';
import '../providers/library_provider.dart';
import '../providers/reader_annotations_provider.dart';
import '../signing/signature_sheet.dart';
import 'reader_scroll_mode.dart';
import 'reading_progress_saver.dart';
import 'widgets/annotation_toolbox.dart';
import 'widgets/floating_page_note.dart';
import 'widgets/note_edit_sheet.dart';
import 'widgets/reader_sidebar.dart';
import 'widgets/save_annotations_sheet.dart';
import 'widgets/signed_pdf_page.dart';

/// Lector PDF de alto rendimiento (pdfx) con filtro Ébano.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  late final PdfController _controller;
  ReadingProgressSaver? _progressSaver;
  ReaderAnnotationsProvider? _annotations;
  AppPreferences? _preferences;
  bool _prefsLoaded = false;
  DocumentSigningProvider? _signing;

  ReaderScrollMode _scrollMode = ReaderScrollMode.verticalContinuous;
  bool _ebonyFilter = true;
  bool _controlsVisible = true;
  bool _sidebarVisible = false;
  bool _noteDismissed = false;
  bool _exiting = false;
  int _pagesCount = 0;
  int _currentPage = 1;
  String? _error;
  Map<int, Size> _pageSizes = const {};
  PdfDocument? _openedDocument;
  late Future<PdfDocument> _documentFuture;
  int _pageSizeCacheGeneration = 0;
  int _documentGeneration = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final initialPage = math.max(1, widget.book.lastPageRead);
    _currentPage = initialPage;

    // Conservamos el Future para cerrar el documento aunque el usuario
    // salga antes de onDocumentLoaded.
    _documentFuture = PdfDocument.openFile(widget.book.filePath);
    _controller = PdfController(
      document: _documentFuture,
      initialPage: initialPage,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final datasource = context.read<LibraryLocalDatasource>();

    final bookId = widget.book.id;

    if (!_prefsLoaded) {
      _prefsLoaded = true;
      _preferences = context.read<AppPreferences?>();
      final prefs = _preferences;
      if (prefs != null) {
        _ebonyFilter = prefs.ebonyFilter;
        _scrollMode = ReaderScrollMode.values.firstWhere(
          (mode) => mode.name == prefs.scrollModeName,
          orElse: () => ReaderScrollMode.verticalContinuous,
        );
      }
    }

    if (_progressSaver == null) {
      final saver = ReadingProgressSaver(datasource);
      if (bookId != null) {
        saver.attach(bookId: bookId, initialPage: _currentPage);
      }
      _progressSaver = saver;
    }

    if (_annotations == null) {
      final annotations = ReaderAnnotationsProvider(datasource);
      _annotations = annotations;
      annotations.addListener(_onAnnotationsChanged);
      if (bookId != null) {
        unawaited(_loadAnnotations(annotations, bookId));
      }
    }

    if (_signing == null) {
      final signing = DocumentSigningProvider(datasource);
      _signing = signing;
      signing.addListener(_onSigningChanged);
      unawaited(_loadSigning(signing));
    }
  }

  Future<void> _loadAnnotations(
    ReaderAnnotationsProvider annotations,
    int bookId,
  ) async {
    await annotations.loadForBook(bookId);
    if (!mounted || !identical(_annotations, annotations)) return;
    final error = annotations.error;
    if (error == null) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_msg(error)),
        action: SnackBarAction(
          label: l10n.retry,
          onPressed: () {
            annotations.clearError();
            unawaited(_loadAnnotations(annotations, bookId));
          },
        ),
      ),
    );
    annotations.clearError();
  }

  Future<void> _loadSigning(DocumentSigningProvider signing) async {
    await signing.loadForBook(widget.book);
    if (!mounted || !identical(_signing, signing)) return;
    final error = signing.error;
    if (error == null) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_msg(error)),
        action: SnackBarAction(
          label: l10n.retry,
          onPressed: () {
            signing.clearError();
            unawaited(_loadSigning(signing));
          },
        ),
      ),
    );
    signing.clearError();
  }

  void _onAnnotationsChanged() {
    if (mounted) setState(() {});
  }

  void _onSigningChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    // Cancela el barrido de tamaños antes de cerrar el documento nativo.
    _pageSizeCacheGeneration++;
    _annotations?.removeListener(_onAnnotationsChanged);
    _annotations?.dispose();
    _signing?.removeListener(_onSigningChanged);
    _signing?.dispose();
    // El guardado fiable ocurre en _onExit / lifecycle; aquí best-effort.
    final saver = _progressSaver;
    _progressSaver = null;
    if (saver != null) {
      // forceTouch: actualiza last_read_at aunque no cambie de página.
      unawaited(saver.saveNow(page: _currentPage, forceTouch: true));
      saver.dispose();
    }
    _controller.dispose();
    // PdfController.dispose() no cierra el PdfDocument nativo (fuga PDFium).
    final document = _openedDocument;
    _openedDocument = null;
    if (document != null && !document.isClosed) {
      unawaited(() async {
        try {
          await document.close();
        } catch (_) {
          // Best-effort al salir del lector.
        }
      }());
    } else {
      // Carga aún pendiente o fallida: cierra al resolver el Future.
      unawaited(_closeDocumentWhenReady(_documentFuture));
    }
    super.dispose();
  }

  Future<void> _closeDocumentWhenReady(Future<PdfDocument> future) async {
    try {
      final document = await future;
      if (!document.isClosed) {
        await document.close();
      }
    } catch (_) {
      // Apertura fallida: nada que cerrar.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Evita escrituras redundantes en blips iOS (inactive/hidden frecuentes).
    if (state == AppLifecycleState.paused) {
      final saver = _progressSaver;
      if (saver == null) return;
      unawaited(saver.saveNow(page: _currentPage, forceTouch: true));
    }
  }

  String _msg(String key, {String? arg}) =>
      AppLocalizations.of(context).message(key, arg: arg);

  Future<void> _onExit() async {
    if (_exiting) return;
    if (_signing?.exporting == true) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.waitForExport)),
        );
      }
      return;
    }
    _exiting = true;
    try {
      final saver = _progressSaver;
      if (saver != null) {
        await saver.saveNow(page: _currentPage, forceTouch: true);
      }
      if (!mounted) return;
      Navigator.of(context).pop(_currentPage);
    } catch (_) {
      _exiting = false;
      rethrow;
    }
  }

  void _onPageChanged(int page) {
    if (_disposed || _exiting) return;
    _currentPage = page;
    _progressSaver?.onPageChanged(page);
    _noteDismissed = false;
    if (mounted) setState(() {});
  }

  void _jumpToPage(int page) {
    if (page < 1) return;
    final maxPage = _pagesCount > 0 ? _pagesCount : page;
    final target = page > maxPage ? maxPage : page;
    _controller.jumpToPage(target);
    setState(() {
      _currentPage = target;
      _sidebarVisible = false;
      _noteDismissed = false;
    });
  }

  Future<void> _toggleScrollMode() async {
    final next = _scrollMode == ReaderScrollMode.verticalContinuous
        ? ReaderScrollMode.horizontalPaged
        : ReaderScrollMode.verticalContinuous;
    setState(() => _scrollMode = next);
    final prefs = _preferences;
    if (prefs == null) return;
    while (mounted) {
      final snapshot = _scrollMode;
      await prefs.setScrollModeName(snapshot.name);
      if (!mounted || _scrollMode == snapshot) return;
    }
  }

  Future<void> _toggleFilter() async {
    final next = !_ebonyFilter;
    setState(() => _ebonyFilter = next);
    final prefs = _preferences;
    if (prefs == null) return;
    while (mounted) {
      final snapshot = _ebonyFilter;
      await prefs.setEbonyFilter(snapshot);
      if (!mounted || _ebonyFilter == snapshot) return;
    }
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  void _toggleSidebar() {
    setState(() => _sidebarVisible = !_sidebarVisible);
  }

  Future<void> _toggleBookmark() async {
    final annotations = _annotations;
    if (annotations == null) return;

    // Fija la página: el usuario puede hacer scroll durante el await / diálogo.
    final page = _currentPage;
    final completed = await annotations.toggleBookmark(page);
    if (completed || !mounted) {
      if (annotations.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_msg(annotations.error!))),
        );
      }
      return;
    }

    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.panel,
        title: Text(l10n.removeBookmark),
        content: Text(l10n.removeBookmarkWithNoteConfirm(page)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await annotations.toggleBookmark(page, force: true);
      if (annotations.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_msg(annotations.error!))),
        );
      }
    }
  }

  Future<void> _editNote() async {
    final annotations = _annotations;
    final page = _currentPage;
    final existing = annotations?.bookmarkForPage(page);
    final l10n = AppLocalizations.of(context);
    final result = await showNoteEditSheet(
      context,
      pageNumber: page,
      initialText: existing?.noteText,
      title: l10n.pageNoteTitle,
    );
    if (result == null || !mounted || annotations == null) return;
    await annotations.saveNote(pageNumber: page, noteText: result);
    if (!mounted) return;
    if (annotations.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_msg(annotations.error!))),
      );
      return;
    }
    setState(() => _noteDismissed = false);
  }

  void _toggleAnnotationToolbox() {
    // Firma y anotación no comparten gestos: al abrir la caja se cancela colocación.
    if (_signing?.placementMode == true) {
      _signing?.cancelPlacementMode();
    }
    _annotations?.toggleToolbox();
    setState(() {});
  }

  Future<void> _createAnnotationRect({
    required int pageNumber,
    required AnnotationTool tool,
    required double x,
    required double y,
    required double width,
    required double height,
    List<List<List<double>>>? strokes,
  }) async {
    final provider = _annotations;
    final type = tool.annotationType;
    if (provider == null || type == null) return;
    if (pageNumber < 1) return;

    final l10n = AppLocalizations.of(context);
    final typeLabel = type.label(l10n);
    String? text;
    if (tool.needsText) {
      text = await showNoteEditSheet(
        context,
        pageNumber: pageNumber,
        title: typeLabel,
        hintText: l10n.writeTypeHint(typeLabel.toLowerCase()),
      );
      if (text == null || !mounted) return;
      if (text.trim().isEmpty) return;
    }

    final created = await provider.addAnnotation(
      pageNumber: pageNumber,
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
      text: text,
      strokes: strokes,
    );
    if (!mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_msg(provider.error!))),
      );
      return;
    }
    if (created == null) return;

    // Las herramientas de texto se sueltan; el marcado queda activo para seguir.
    if (tool.needsText) {
      provider.clearTool();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.annotationSaved(typeLabel, pageNumber)),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openAnnotation(PageAnnotation annotation) async {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final typeLabel = annotation.type.label(l10n);

    if (annotation.type.needsText || annotation.hasText) {
      final action = await showModalBottomSheet<_AnnotationAction>(
        context: context,
        backgroundColor: colors.panel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        ),
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    annotation.type.icon,
                    color: AppColors.ebonyAccent,
                  ),
                  title: Text(
                    typeLabel,
                    style: const TextStyle(color: AppColors.ebonyAccent),
                  ),
                  subtitle: Text(
                    annotation.hasText
                        ? annotation.text!
                        : l10n.pageNumber(annotation.pageNumber),
                  ),
                ),
                const Divider(height: 1),
                if (annotation.type.needsText)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(l10n.editText),
                    onTap: () =>
                        Navigator.of(context).pop(_AnnotationAction.edit),
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.delete),
                  onTap: () =>
                      Navigator.of(context).pop(_AnnotationAction.delete),
                ),
                ListTile(
                  leading: Icon(Icons.close, color: colors.textMuted),
                  title: Text(l10n.cancel),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
      );

      if (!mounted || action == null) return;
      if (action == _AnnotationAction.delete) {
        await _confirmDeleteAnnotation(annotation);
        return;
      }
      if (action == _AnnotationAction.edit) {
        final result = await showNoteEditSheet(
          context,
          pageNumber: annotation.pageNumber,
          initialText: annotation.text,
          title: typeLabel,
          hintText: l10n.editTypeHint(typeLabel.toLowerCase()),
        );
        if (result == null || !mounted) return;
        await _annotations?.updateAnnotationText(
          annotation: annotation,
          text: result,
        );
        if (_annotations?.error != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_msg(_annotations!.error!))),
          );
        }
      }
      return;
    }

    // Marcado / subrayado: acciones rápidas.
    final action = await showModalBottomSheet<_AnnotationAction>(
      context: context,
      backgroundColor: colors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  annotation.type.icon,
                  color: AppColors.ebonyAccent,
                ),
                title: Text(
                  '$typeLabel · ${l10n.pageNumber(annotation.pageNumber)}',
                  style: const TextStyle(color: AppColors.ebonyAccent),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.delete),
                onTap: () =>
                    Navigator.of(context).pop(_AnnotationAction.delete),
              ),
              ListTile(
                leading: Icon(Icons.close, color: colors.textMuted),
                title: Text(l10n.cancel),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == _AnnotationAction.delete) {
      await _confirmDeleteAnnotation(annotation);
    }
  }

  Future<void> _confirmDeleteAnnotation(PageAnnotation annotation) async {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final typeLabel = annotation.type.label(l10n);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.panel,
        title: Text(
          l10n.deleteAnnotationTitle(typeLabel.toLowerCase()),
          style: const TextStyle(color: AppColors.ebonyAccent),
        ),
        content: Text(
          l10n.deleteAnnotationConfirm(annotation.pageNumber),
          style: TextStyle(color: colors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel, style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppColors.ebonyAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _annotations?.deleteAnnotation(annotation);
      if (!mounted) return;
      if (_annotations?.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_msg(_annotations!.error!))),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.annotationDeleted(typeLabel)),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _signDocument() async {
    if (_signing?.saving == true ||
        _signing?.loading == true ||
        _signing?.exporting == true) {
      return;
    }
    // Anotación y firma no comparten gestos.
    _annotations?.setToolboxVisible(false);
    // Primero colocar zona en la página; luego se abre el formulario.
    _signing?.beginPlacementMode();
    setState(() {});
  }

  Future<void> _openSignatureSheetAt(int pageNumber, double x, double y) async {
    if (_signing?.saving == true ||
        _signing?.loading == true ||
        _signing?.exporting == true) {
      return;
    }
    if (pageNumber < 1) return;
    _signing?.placeSignatureAt(offsetX: x, offsetY: y);

    final draft = await showSignatureSheet(
      context,
      pageNumber: pageNumber,
      initialSignerName: _signing?.lastSignerName,
      initialRole: _signing?.lastRole,
      initialOffsetX: x,
      initialOffsetY: y,
      templates: _signing?.templates ?? const [],
    );
    if (!mounted) return;
    if (draft == null) {
      _signing?.clearPendingPlacement();
      // Permite reintentar la colocación sin volver a pulsar firmar.
      _signing?.beginPlacementMode();
      setState(() {});
      return;
    }
    if (_signing?.saving == true) {
      // No abandona al usuario: mantiene modo colocación para reintentar.
      _signing?.clearPendingPlacement();
      _signing?.beginPlacementMode();
      setState(() {});
      return;
    }

    final saved = await _signing?.signPage(
      pageNumber: pageNumber,
      draft: draft,
    );
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final error = _signing?.error;
    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error != null ? _msg(error) : l10n.signDocumentFailed,
          ),
        ),
      );
      _signing?.clearError();
      return;
    }

    final warning = error;
    _signing?.clearError();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          warning != null
              ? _msg(warning)
              : l10n.signedAsRole(
                  saved.role.label(l10n).toLowerCase(),
                  saved.signingOrder,
                ),
        ),
        action: SnackBarAction(
          label: l10n.exportAction,
          onPressed: () {
            if (!mounted) return;
            unawaited(_exportSignedPdf());
          },
        ),
      ),
    );
  }

  Future<void> _cachePageSizes(
    PdfDocument document,
    int generation,
  ) async {
    final sizes = <int, Size>{};
    try {
      for (var pageNumber = 1; pageNumber <= document.pagesCount; pageNumber++) {
        if (!mounted ||
            generation != _pageSizeCacheGeneration ||
            document.isClosed) {
          return;
        }
        final page = await document.getPage(pageNumber);
        try {
          if (page.width.isFinite &&
              page.height.isFinite &&
              page.width >= 1 &&
              page.height >= 1) {
            sizes[pageNumber] = Size(page.width, page.height);
          }
        } finally {
          await page.close();
        }
      }
    } catch (_) {
      // Salida rápida / documento cerrado: cancelación silenciosa.
      return;
    }
    if (!mounted || generation != _pageSizeCacheGeneration) return;
    setState(() => _pageSizes = sizes);
  }

  Future<void> _shareDocument() async {
    final l10n = AppLocalizations.of(context);
    final path = widget.book.filePath;
    final title = widget.book.title;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    final file = File(path);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shareDocumentFailed)),
      );
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'application/pdf')],
          subject: title,
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ReaderScreen._shareDocument: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shareDocumentFailed)),
      );
    }
  }

  Future<void> _exportSignedPdf() async {
    if (_signing?.exporting == true) return;
    final l10n = AppLocalizations.of(context);
    final result = await _signing?.exportSignedPdf(
      signedMarker: l10n.signedMarker,
      roleLabelOf: (role) => role.label(l10n),
    );
    if (!mounted) return;
    if (result == null) {
      final error = _signing?.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error != null ? _msg(error) : l10n.exportSignedFailed,
          ),
        ),
      );
      _signing?.clearError();
      return;
    }
    try {
      await context.read<LibraryProvider>().load();
    } catch (_) {
      // El PDF ya está exportado; fallar el refresh no invalida el resultado.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.exportSignedSuccess(result.manifest.signedFileName),
        ),
      ),
    );
  }

  Future<void> _promptSaveAnnotations() async {
    final annotations = _annotations;
    if (annotations == null || !annotations.hasAnnotations) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorNeedAnnotations)),
      );
      return;
    }
    if (annotations.savingToPdf || _signing?.exporting == true) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.waitForExport)),
      );
      return;
    }

    final target = await showSaveAnnotationsSheet(context);
    if (!mounted || target == null) return;
    await _saveAnnotations(target);
  }

  Future<void> _saveAnnotations(AnnotatedPdfSaveTarget target) async {
    final annotations = _annotations;
    if (annotations == null) return;
    final l10n = AppLocalizations.of(context);

    final result = await annotations.saveAnnotationsToPdf(
      book: widget.book,
      target: target,
      annotatedMarker: 'annotated',
      prepareOverwrite: target == AnnotatedPdfSaveTarget.currentDocument
          ? _prepareDocumentOverwrite
          : null,
    );

    if (!mounted) return;
    if (result == null) {
      final error = annotations.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error != null ? _msg(error) : l10n.exportAnnotatedFailed,
          ),
        ),
      );
      annotations.clearError();
      return;
    }

    if (target == AnnotatedPdfSaveTarget.currentDocument) {
      await _reloadDocumentAfterOverwrite();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveAnnotationsSuccessDocument)),
      );
      return;
    }

    try {
      await context.read<LibraryProvider>().load();
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.saveAnnotationsSuccessCopy(result.fileName)),
      ),
    );
  }

  /// Cierra el PDF abierto para poder sobrescribir el archivo en disco.
  Future<void> _prepareDocumentOverwrite() async {
    final opened = _openedDocument;
    _openedDocument = null;
    if (opened != null && !opened.isClosed) {
      try {
        await opened.close();
      } catch (_) {}
    } else {
      await _closeDocumentWhenReady(_documentFuture);
    }
  }

  Future<void> _reloadDocumentAfterOverwrite() async {
    if (!mounted) return;
    final page = _currentPage;
    _documentGeneration++;
    _pageSizeCacheGeneration++;
    final nextFuture = PdfDocument.openFile(widget.book.filePath);
    _documentFuture = nextFuture;
    await _controller.loadDocument(nextFuture, initialPage: page);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _confirmDeleteSignature(DocumentSignature signature) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = AppPalette.of(context);
        return AlertDialog(
          backgroundColor: colors.panel,
          title: Text(l10n.deleteSignatureTitle),
          content: Text(
            l10n.deleteSignatureConfirm(
              signature.signerName,
              signature.pageNumber,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel, style: TextStyle(color: colors.text)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                l10n.delete,
                style: const TextStyle(color: AppColors.ebonyAccent),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final deleted = await _signing?.deleteSignature(signature) ?? false;
    if (!mounted) return;
    if (!deleted) {
      final error = _signing?.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error != null ? _msg(error) : l10n.deleteSignatureFailed,
          ),
        ),
      );
      _signing?.clearError();
    }
  }

  Future<void> _deleteBookmark(Bookmark bookmark) async {
    final annotations = _annotations;
    if (annotations == null) return;

    final hasNote =
        bookmark.noteText != null && bookmark.noteText!.trim().isNotEmpty;
    if (hasNote) {
      final colors = AppPalette.of(context);
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: colors.panel,
          title: Text(l10n.deleteBookmarkTitle),
          content: Text(
            l10n.deleteBookmarkWithNoteConfirm(bookmark.pageNumber),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.delete, style: TextStyle(color: colors.accent)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await annotations.deleteBookmark(bookmark);
    if (annotations.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_msg(annotations.error!))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final scaffoldBg =
        _ebonyFilter ? EbonyPdfFilter.background : colors.background;
    final annotations = _annotations;
    final signing = _signing;
    final currentBookmark = annotations?.bookmarkForPage(_currentPage);
    final pageSignatures = signing?.signaturesForPage(_currentPage) ?? const [];
    final noteText = currentBookmark?.noteText;
    final hasNote = noteText != null && noteText.isNotEmpty;
    final isBookmarked = currentBookmark != null;
    final toolboxVisible = annotations?.toolboxVisible ?? false;
    final activeTool = annotations?.activeTool ?? AnnotationTool.none;
    final pageAnnotations =
        annotations?.annotationsForPage(_currentPage) ?? const [];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_signing?.exporting == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).waitForExport),
            ),
          );
          return;
        }
        if (_signing?.placementMode == true) {
          _signing?.cancelPlacementMode();
          setState(() {});
          return;
        }
        if (_sidebarVisible) {
          setState(() => _sidebarVisible = false);
          return;
        }
        if (toolboxVisible) {
          annotations?.setToolboxVisible(false);
          return;
        }
        await _onExit();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _ebonyFilter
            ? SystemUiOverlayStyle.light
            : (Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark),
        child: Scaffold(
          backgroundColor: scaffoldBg,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(child: _buildPdfView(colors)),
                if (hasNote && !_noteDismissed)
                  Positioned(
                    right: 12,
                    bottom: _controlsVisible
                        ? (toolboxVisible ? 168 : 64)
                        : 16,
                    child: FloatingPageNote(
                      noteText: noteText,
                      pageNumber: _currentPage,
                      onEdit: _editNote,
                      onDismiss: () => setState(() => _noteDismissed = true),
                    ),
                  ),
                if (_controlsVisible)
                  _buildTopBar(
                    colors,
                    isBookmarked,
                    signing,
                    toolboxVisible: toolboxVisible,
                  ),
                if (_controlsVisible && !toolboxVisible)
                  _buildBottomBar(
                    colors,
                    isBookmarked: isBookmarked,
                    signatureCount: pageSignatures.length,
                    annotationCount: pageAnnotations.length,
                  ),
                if (_controlsVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnnotationToolbox(
                      visible: toolboxVisible,
                      activeTool: activeTool,
                      isBookmarked: isBookmarked,
                      pageNumber: _currentPage,
                      annotationCount: pageAnnotations.length,
                      inkColor: annotations?.inkColor,
                      strokeSizeIndex: annotations?.strokeSizeIndex ?? 2,
                      canUndo: annotations?.canUndo ?? false,
                      canRedo: annotations?.canRedo ?? false,
                      canSave: (annotations?.hasAnnotations ?? false) &&
                          !(_signing?.exporting ?? false),
                      saving: annotations?.savingToPdf ?? false,
                      onToggleBookmark: () {
                        unawaited(_toggleBookmark());
                      },
                      onSelectTool: (tool) {
                        if (_signing?.placementMode == true) {
                          _signing?.cancelPlacementMode();
                        }
                        annotations?.selectTool(tool);
                        setState(() {});
                      },
                      onInkColorChanged: (color) {
                        annotations?.setInkColor(color);
                        setState(() {});
                      },
                      onStrokeSizeChanged: (index) {
                        annotations?.setStrokeSizeIndex(index);
                        setState(() {});
                      },
                      onUndo: () {
                        unawaited(annotations?.undo());
                      },
                      onRedo: () {
                        unawaited(annotations?.redo());
                      },
                      onSave: () {
                        unawaited(_promptSaveAnnotations());
                      },
                      onClearTool: () => annotations?.clearTool(),
                      onClose: () => annotations?.setToolboxVisible(false),
                    ),
                  ),
                if (!_controlsVisible)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: AppLocalizations.of(context).showControls,
                      onPressed: _toggleControls,
                      style: IconButton.styleFrom(
                        backgroundColor: colors.panel.withValues(alpha: 0.85),
                      ),
                      icon: Icon(Icons.more_horiz, color: colors.accent),
                    ),
                  ),
                // Acceso rápido al icono de acento aunque los controles estén ocultos.
                if (!_controlsVisible)
                  Positioned(
                    top: 8,
                    right: 56,
                    child: IconButton(
                      tooltip: AppLocalizations.of(context).annotationTools,
                      onPressed: () {
                        setState(() => _controlsVisible = true);
                        _toggleAnnotationToolbox();
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: colors.panel.withValues(alpha: 0.85),
                      ),
                      icon: const Icon(
                        Icons.border_color,
                        color: AppColors.ebonyAccent,
                      ),
                    ),
                  ),
                ReaderSidebar(
                  visible: _sidebarVisible,
                  pagesCount: _pagesCount,
                  currentPage: _currentPage,
                  bookmarks: annotations?.bookmarks ?? const [],
                  annotations: annotations?.annotations ?? const [],
                  signatures: signing?.signatures ?? const [],
                  onClose: () => setState(() => _sidebarVisible = false),
                  onOpenPage: _jumpToPage,
                  onDeleteBookmark: _deleteBookmark,
                  onDeleteAnnotation: (a) =>
                      unawaited(_confirmDeleteAnnotation(a)),
                  onOpenAnnotation: _openAnnotation,
                  onDeleteSignature: _confirmDeleteSignature,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfView(AppPalette colors) {
    final l10n = AppLocalizations.of(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.text),
          ),
        ),
      );
    }

    final isVertical = _scrollMode.isVertical;

    final signing = _signing;
    final annotations = _annotations;
    final activeTool = annotations?.activeTool ?? AnnotationTool.none;
    final placementMode = signing?.placementMode ?? false;
    final annotationsLayerEnabled = !placementMode && !_sidebarVisible;
    final drawingLocksNavigation =
        placementMode || activeTool != AnnotationTool.none;
    final scaffoldBg =
        _ebonyFilter ? EbonyPdfFilter.background : colors.background;

    return PdfView(
      // Sin ValueKey: cambiar scrollDirection no recrea el PdfView
      // (evita fugas de listeners/caches de pdfx al alternar modo).
      controller: _controller,
      scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
      pageSnapping: !isVertical,
      // Con herramienta de anotación o colocación de firma, no desplazar
      // páginas: el trazo (dedo/S-Pen) debe ser estable.
      physics: drawingLocksNavigation
          ? const NeverScrollableScrollPhysics()
          : (isVertical
              ? const BouncingScrollPhysics()
              : const PageScrollPhysics()),
      backgroundDecoration: BoxDecoration(color: scaffoldBg),
      onPageChanged: _onPageChanged,
      onDocumentLoaded: (document) {
        if (!mounted) return;
        _openedDocument = document;
        final count = document.pagesCount;
        setState(() {
          _pagesCount = count;
          _error = null;
        });
        // PDF truncado/reemplazado: no quedarse más allá del final.
        if (count >= 1 && _currentPage > count) {
          final clamped = count;
          _controller.jumpToPage(clamped);
          setState(() => _currentPage = clamped);
          _progressSaver?.onPageChanged(clamped);
        }
        final generation = ++_pageSizeCacheGeneration;
        unawaited(_cachePageSizes(document, generation));
      },
      onDocumentError: (error) {
        if (!mounted) return;
        // En producción no filtramos el detalle técnico del motor PDF.
        final detail = kDebugMode ? '$error' : '';
        final message = detail.isEmpty
            ? l10n.openPdfError('').split('\n').first
            : l10n.openPdfError(detail);
        setState(() => _error = message);
      },
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => Center(
          child: CircularProgressIndicator(color: colors.accent),
        ),
        pageLoaderBuilder: (_) => Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.accent,
            ),
          ),
        ),
        errorBuilder: (_, error) => Center(
          child: Text(
            l10n.pageLoadError,
            style: TextStyle(color: colors.text),
          ),
        ),
        pageBuilder: (context, pageImage, index, document) {
          final pageNumber = index + 1;
          final pageSize = _pageSizes[pageNumber] ?? const Size(595, 842);
          // Solo la página actual captura gestos de dibujo; el resto muestra
          // anotaciones y permite abrir/eliminar sin bloquear el scroll.
          final pageTool = pageNumber == _currentPage && annotationsLayerEnabled
              ? activeTool
              : AnnotationTool.none;
          return PhotoViewGalleryPageOptions.customChild(
            child: SignedPdfPage(
              pageImageFuture: pageImage,
              pageNumber: pageNumber,
              fallbackSize: pageSize,
              documentGeneration: _documentGeneration,
              signatures: signing?.signaturesForPage(pageNumber) ?? const [],
              annotations:
                  annotations?.annotationsForPage(pageNumber) ?? const [],
              activeTool: pageTool,
              annotationsEnabled: annotationsLayerEnabled,
              inkColor: annotations?.activeInkColor,
              strokeWidthPx: annotations?.activeStrokeWidthPx,
              ebonyFilter: _ebonyFilter,
              // Solo la página actual acepta toques de colocación (scroll continuo).
              placementMode:
                  (signing?.placementMode ?? false) && pageNumber == _currentPage,
              onPlaceTap: _openSignatureSheetAt,
              onCreateAnnotation: _createAnnotationRect,
              onOpenAnnotation: _openAnnotation,
              onDeleteAnnotation: _confirmDeleteAnnotation,
              signaturesInteractive: !(signing?.exporting ?? false) &&
                  !(signing?.saving ?? false) &&
                  !(signing?.loading ?? false),
              onMove: (signature, x, y) async {
                final messenger = ScaffoldMessenger.of(context);
                final l10n = AppLocalizations.of(context);
                final moved = await _signing?.moveSignature(
                  signature: signature,
                  offsetX: x,
                  offsetY: y,
                );
                if (!(moved ?? false) && mounted) {
                  final error = _signing?.error;
                  if (error != null) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.message(error))),
                    );
                    _signing?.clearError();
                  }
                }
                return moved ?? false;
              },
              onDelete: _confirmDeleteSignature,
            ),
            // Debe coincidir con el SizedBox de SignedPdfPage (puntos PDF).
            childSize: pageSize,
            // Evita que PhotoView robe el pan/zoom mientras se dibuja
            // con dedo o S-Pen.
            disableGestures: pageTool != AnnotationTool.none ||
                ((signing?.placementMode ?? false) &&
                    pageNumber == _currentPage),
            initialScale: PhotoViewComputedScale.contained * 1.0,
            minScale: PhotoViewComputedScale.contained * 1.0,
            maxScale: PhotoViewComputedScale.contained * 3.0,
            heroAttributes:
                PhotoViewHeroAttributes(tag: '${document.id}-$index'),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(
    AppPalette colors,
    bool isBookmarked,
    DocumentSigningProvider? signing, {
    required bool toolboxVisible,
  }) {
    final l10n = AppLocalizations.of(context);
    final placement = signing?.placementMode == true;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: colors.panel.withValues(alpha: 0.94),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: l10n.menuToc,
              onPressed: _toggleSidebar,
              icon: Icon(Icons.menu, color: colors.accent),
            ),
            IconButton(
              tooltip: placement ? l10n.cancelPlacement : l10n.back,
              onPressed: () {
                if (placement) {
                  signing?.cancelPlacementMode();
                  setState(() {});
                  return;
                }
                _onExit();
              },
              icon: Icon(Icons.arrow_back, color: colors.text),
            ),
            Expanded(
              child: Text(
                widget.book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            // Icono bronce de anotación siempre visible.
            IconButton(
              tooltip: toolboxVisible
                  ? l10n.closeAnnotationTools
                  : l10n.annotationTools,
              onPressed: _toggleAnnotationToolbox,
              style: IconButton.styleFrom(
                backgroundColor: toolboxVisible
                    ? AppColors.ebonyAccent.withValues(alpha: 0.22)
                    : null,
              ),
              icon: Icon(
                Icons.border_color,
                color: AppColors.ebonyAccent,
                size: toolboxVisible ? 24 : 22,
              ),
            ),
            IconButton(
              tooltip: l10n.scrollModeTooltip(
                _scrollMode.localizedLabel(l10n),
              ),
              onPressed: _toggleScrollMode,
              icon: Icon(
                _scrollMode.isVertical ? Icons.swap_vert : Icons.swap_horiz,
                color: colors.accent,
              ),
            ),
            PopupMenuButton<_ReaderToolAction>(
              tooltip: l10n.options,
              icon: Icon(Icons.more_vert, color: colors.textMuted),
              onSelected: (action) {
                switch (action) {
                  case _ReaderToolAction.bookmark:
                    _toggleBookmark();
                  case _ReaderToolAction.note:
                    _editNote();
                  case _ReaderToolAction.ebonyFilter:
                    _toggleFilter();
                  case _ReaderToolAction.hideControls:
                    _toggleControls();
                  case _ReaderToolAction.sign:
                    if (placement) {
                      signing?.cancelPlacementMode();
                      setState(() {});
                      return;
                    }
                    _signDocument();
                  case _ReaderToolAction.share:
                    unawaited(_shareDocument());
                  case _ReaderToolAction.export:
                    _exportSignedPdf();
                  case _ReaderToolAction.saveAnnotations:
                    unawaited(_promptSaveAnnotations());
                }
              },
              itemBuilder: (context) {
                final signBusy = signing?.saving == true ||
                    signing?.loading == true ||
                    signing?.exporting == true;
                final annotationsBusy =
                    _annotations?.savingToPdf == true;
                final exportEnabled = signing != null &&
                    signing.hasSignatures &&
                    !signing.exporting &&
                    !signing.saving &&
                    !placement;
                final saveAnnotationsEnabled =
                    (_annotations?.hasAnnotations ?? false) &&
                        !annotationsBusy &&
                        !(signing?.exporting ?? false);

                return [
                  PopupMenuItem(
                    value: _ReaderToolAction.bookmark,
                    child: _ReaderToolMenuRow(
                      icon: isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      label: isBookmarked
                          ? l10n.removeBookmark
                          : l10n.addBookmark,
                      color: colors.accent,
                    ),
                  ),
                  PopupMenuItem(
                    value: _ReaderToolAction.note,
                    child: _ReaderToolMenuRow(
                      icon: Icons.sticky_note_2_outlined,
                      label: l10n.addNote,
                      color: colors.accent,
                    ),
                  ),
                  PopupMenuItem(
                    value: _ReaderToolAction.ebonyFilter,
                    child: _ReaderToolMenuRow(
                      icon: _ebonyFilter
                          ? Icons.dark_mode
                          : Icons.dark_mode_outlined,
                      label: _ebonyFilter
                          ? l10n.filterEbonyOff
                          : l10n.filterEbonyOn,
                      color: _ebonyFilter ? colors.accent : colors.textMuted,
                    ),
                  ),
                  PopupMenuItem(
                    value: _ReaderToolAction.hideControls,
                    child: _ReaderToolMenuRow(
                      icon: Icons.fullscreen,
                      label: l10n.hideControls,
                      color: colors.textMuted,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _ReaderToolAction.share,
                    enabled: !annotationsBusy && !signBusy,
                    child: _ReaderToolMenuRow(
                      icon: Icons.ios_share_outlined,
                      label: l10n.shareDocument,
                      color: AppColors.ebonyAccent,
                    ),
                  ),
                  PopupMenuItem(
                    value: _ReaderToolAction.saveAnnotations,
                    enabled: saveAnnotationsEnabled,
                    child: _ReaderToolMenuRow(
                      icon: Icons.save_outlined,
                      label: l10n.saveAnnotations,
                      color: saveAnnotationsEnabled
                          ? AppColors.ebonyAccent
                          : colors.textMuted,
                    ),
                  ),
                  PopupMenuItem(
                    value: _ReaderToolAction.sign,
                    enabled: !signBusy,
                    child: _ReaderToolMenuRow(
                      icon: placement ? Icons.close : Icons.draw_outlined,
                      label: placement
                          ? l10n.cancelPlacement
                          : l10n.signDocument,
                      color: AppColors.ebonyAccent,
                    ),
                  ),
                  PopupMenuItem(
                    value: _ReaderToolAction.export,
                    enabled: exportEnabled,
                    child: _ReaderToolMenuRow(
                      icon: Icons.verified_outlined,
                      label: l10n.exportSignedPdf,
                      color: exportEnabled
                          ? AppColors.ebonyAccent
                          : colors.textMuted,
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    AppPalette colors, {
    required bool isBookmarked,
    required int signatureCount,
    required int annotationCount,
  }) {
    final l10n = AppLocalizations.of(context);
    final label =
        _pagesCount > 0 ? '$_currentPage / $_pagesCount' : '$_currentPage';

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          color: colors.panel.withValues(alpha: 0.94),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
          children: [
            if (isBookmarked) ...[
              Icon(Icons.bookmark, size: 16, color: colors.accent),
              const SizedBox(width: 6),
            ],
            if (signatureCount > 0) ...[
              Icon(Icons.draw, size: 16, color: AppColors.ebonyAccent),
              const SizedBox(width: 4),
              Text(
                '$signatureCount',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.ebonyAccent,
                    ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.accent,
                  ),
            ),
            if (annotationCount > 0) ...[
              const SizedBox(width: 10),
              const Icon(
                Icons.border_color,
                size: 14,
                color: AppColors.ebonyAccent,
              ),
              const SizedBox(width: 4),
              Text(
                '$annotationCount',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.ebonyAccent,
                    ),
              ),
            ],
            const Spacer(),
            Text(
              _scrollMode.localizedLabel(l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_ebonyFilter) ...[
              const SizedBox(width: 12),
              Text(
                l10n.themeEbony,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.accent,
                    ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

enum _AnnotationAction { edit, delete }

enum _ReaderToolAction {
  bookmark,
  note,
  ebonyFilter,
  hideControls,
  share,
  saveAnnotations,
  sign,
  export,
}

class _ReaderToolMenuRow extends StatelessWidget {
  const _ReaderToolMenuRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

