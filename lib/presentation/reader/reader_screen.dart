import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
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
import '../../domain/pdf_page_rasterizer.dart';
import '../../domain/pdf_text_service.dart';
import '../../l10n/app_localizations.dart';
import '../providers/document_signing_provider.dart';
import '../providers/library_provider.dart';
import '../providers/reader_annotations_provider.dart';
import '../signing/signature_sheet.dart';
import 'reader_scroll_mode.dart';
import 'reading_progress_saver.dart';
import 'pdf_text_search.dart';
import 'widgets/annotation_toolbox.dart';
import 'widgets/floating_page_note.dart';
import 'widgets/note_edit_sheet.dart';
import 'widgets/reader_sidebar.dart';
import 'widgets/save_annotations_sheet.dart';
import 'widgets/signed_pdf_page.dart';

/// Lector PDF de alto rendimiento (pdfrx + PhotoView) con filtro Ébano.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  /// Zoom/pan de la página actual mientras se dibuja con candado abierto.
  final PhotoViewController _pageZoomController = PhotoViewController();
  /// Extracción de texto del PDF (imantado preciso + selección para copiar).
  PdfTextService? _pdfText;
  List<PdfLineBox> _currentPageLines = const [];
  bool _textSelecting = false;
  String _selectedText = '';
  /// Modo buscador de texto del menú ⋯.
  bool _textSearching = false;
  String _searchQuery = '';
  List<PdfTextMatch> _searchMatches = const [];
  int _searchMatchIndex = 0;
  bool _searchBusy = false;
  int _searchGeneration = 0;
  final TextEditingController _searchFieldController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
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
  bool _didShowMinimizeHint = false;
  int _pagesCount = 0;
  int _currentPage = 1;
  String? _error;
  Map<int, Size> _pageSizes = const {};
  PdfDocument? _openedDocument;
  /// Caché de rasterizaciones PNG por página (invalidada al regenerar el doc).
  final Map<int, Future<Uint8List>> _pageImageFutures = {};
  int _documentGeneration = 0;
  bool _disposed = false;
  bool _openingDocument = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final initialPage = math.max(1, widget.book.lastPageRead);
    _currentPage = initialPage;
    _pageController = PageController(initialPage: initialPage - 1);

    final path = widget.book.filePath;
    _pdfText = PdfTextService(() => File(path).readAsBytes());
    unawaited(_openDocument());
  }

  Future<void> _openDocument() async {
    if (_openingDocument || _disposed) return;
    _openingDocument = true;
    final l10nReady = mounted;
    try {
      final document = await PdfDocument.openFile(widget.book.filePath);
      if (_disposed) {
        await document.dispose();
        return;
      }
      final previous = _openedDocument;
      _openedDocument = document;
      _pageImageFutures.clear();
      final count = document.pages.length;
      final sizes = <int, Size>{};
      for (var i = 0; i < count; i++) {
        final page = document.pages[i];
        if (page.width.isFinite &&
            page.height.isFinite &&
            page.width >= 1 &&
            page.height >= 1) {
          sizes[i + 1] = Size(page.width, page.height);
        }
      }
      if (!mounted) {
        await previous?.dispose();
        return;
      }
      setState(() {
        _pagesCount = count;
        _pageSizes = sizes;
        _error = null;
      });
      if (previous != null) {
        try {
          await previous.dispose();
        } catch (_) {}
      }
      // PDF truncado/reemplazado: no quedarse más allá del final.
      if (count >= 1 && _currentPage > count) {
        final clamped = count;
        _jumpToPage(clamped);
        _progressSaver?.onPageChanged(clamped);
      }
      _maybeShowReaderTip();
    } catch (error) {
      if (!mounted || _disposed) return;
      final detail = kDebugMode ? '$error' : '';
      final l10n = l10nReady ? AppLocalizations.of(context) : null;
      final message = l10n == null
          ? 'Error al abrir el PDF'
          : (detail.isEmpty
              ? l10n.openPdfError('').split('\n').first
              : l10n.openPdfError(detail));
      setState(() => _error = message);
    } finally {
      _openingDocument = false;
    }
  }

  /// Rasteriza una página (lazy) y cachea el Future por generación del doc.
  Future<Uint8List> _pageImageFutureFor(int pageNumber) {
    final cached = _pageImageFutures[pageNumber];
    if (cached != null) return cached;
    final future = () async {
      final doc = _openedDocument;
      if (doc == null || pageNumber < 1 || pageNumber > doc.pages.length) {
        throw StateError('Page $pageNumber unavailable');
      }
      final raster = await rasterizePdfPage(
        doc.pages[pageNumber - 1],
        scale: 2.0,
      );
      return raster.pngBytes;
    }();
    _pageImageFutures[pageNumber] = future;
    return future;
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
      final prefs = _preferences;
      if (prefs != null) {
        annotations.initSnapToText(prefs.snapMarkupToText);
      }
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
    _annotations?.removeListener(_onAnnotationsChanged);
    _annotations?.dispose();
    // Cierra el documento PDFium del servicio de texto (imantado/selección).
    final pdfText = _pdfText;
    _pdfText = null;
    if (pdfText != null) unawaited(pdfText.dispose());
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
    _pageController.dispose();
    _pageZoomController.dispose();
    _searchDebounce?.cancel();
    _searchFieldController.dispose();
    _searchFocusNode.dispose();
    _pageImageFutures.clear();
    final document = _openedDocument;
    _openedDocument = null;
    if (document != null) {
      unawaited(() async {
        try {
          await document.dispose();
        } catch (_) {
          // Best-effort al salir del lector.
        }
      }());
    }
    super.dispose();
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
    _currentPageLines = const [];
    _selectedText = '';
    if (mounted) setState(() {});
    _maybeFetchPageText();
  }

  bool get _needsPageText =>
      _textSelecting ||
      ((_annotations?.snapToText ?? false) &&
          (_annotations?.activeTool.isMarkup ?? false));

  /// Extrae (perezosamente) el texto de la página actual cuando hace falta.
  void _maybeFetchPageText() {
    if (!_needsPageText) return;
    final service = _pdfText;
    if (service == null || _pagesCount < 1) return;
    final page = _currentPage;
    final index = page - 1;
    if (index < 0) return;
    unawaited(() async {
      final lines = await service.linesForPage(index);
      if (!mounted || _currentPage != page) return;
      setState(() => _currentPageLines = lines);
      if (_textSelecting && lines.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).noSelectableText),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }());
  }

  void _enterTextSelection() {
    if (_signing?.placementMode == true) _signing?.cancelPlacementMode();
    if (_textSearching) _exitTextSearch();
    _annotations?.clearTool();
    _annotations?.setToolboxVisible(false);
    _resetPageZoom();
    setState(() {
      _textSelecting = true;
      _selectedText = '';
      _controlsVisible = true;
    });
    _maybeFetchPageText();
  }

  void _exitTextSelection() {
    setState(() {
      _textSelecting = false;
      _selectedText = '';
    });
  }

  void _enterTextSearch() {
    if (_signing?.placementMode == true) _signing?.cancelPlacementMode();
    _annotations?.clearTool();
    _annotations?.setToolboxVisible(false);
    _resetPageZoom();
    setState(() {
      _textSelecting = false;
      _selectedText = '';
      _textSearching = true;
      _controlsVisible = true;
      _searchQuery = _searchFieldController.text;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
    if (_searchQuery.trim().isNotEmpty) {
      unawaited(_runTextSearch(_searchQuery));
    }
  }

  void _exitTextSearch() {
    _searchDebounce?.cancel();
    _searchGeneration++;
    setState(() {
      _textSearching = false;
      _searchMatches = const [];
      _searchMatchIndex = 0;
      _searchBusy = false;
    });
  }

  void _onSearchQueryChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _searchGeneration++;
      setState(() {
        _searchMatches = const [];
        _searchMatchIndex = 0;
        _searchBusy = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_runTextSearch(trimmed));
    });
  }

  Future<void> _runTextSearch(String query) async {
    final service = _pdfText;
    final pageCount = _pagesCount;
    if (service == null || pageCount < 1) {
      setState(() {
        _searchMatches = const [];
        _searchMatchIndex = 0;
        _searchBusy = false;
      });
      return;
    }
    final generation = ++_searchGeneration;
    setState(() => _searchBusy = true);
    final matches = <PdfTextMatch>[];
    for (var i = 0; i < pageCount; i++) {
      if (!mounted || generation != _searchGeneration) return;
      final lines = await service.linesForPage(i);
      if (!mounted || generation != _searchGeneration) return;
      matches.addAll(
        findMatchesInLines(
          lines: lines,
          query: query,
          pageNumber: i + 1,
        ),
      );
    }
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _searchMatches = matches;
      _searchMatchIndex = 0;
      _searchBusy = false;
    });
    if (matches.isNotEmpty) {
      _revealSearchMatch(0);
    }
  }

  void _revealSearchMatch(int index) {
    if (_searchMatches.isEmpty) return;
    final safe = index.clamp(0, _searchMatches.length - 1);
    final match = _searchMatches[safe];
    setState(() => _searchMatchIndex = safe);
    if (match.pageNumber != _currentPage) {
      _jumpToPage(match.pageNumber);
    }
  }

  void _goToPreviousSearchMatch() {
    if (_searchMatches.isEmpty) return;
    final next = (_searchMatchIndex - 1) < 0
        ? _searchMatches.length - 1
        : _searchMatchIndex - 1;
    _revealSearchMatch(next);
  }

  void _goToNextSearchMatch() {
    if (_searchMatches.isEmpty) return;
    final next = (_searchMatchIndex + 1) % _searchMatches.length;
    _revealSearchMatch(next);
  }

  Future<void> _copySelectedText() async {
    final text = _selectedText.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).textCopied),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }

  Future<void> _shareSelectedText() async {
    final text = _selectedText.trim();
    if (text.isEmpty) return;
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (e) {
      if (kDebugMode) debugPrint('ReaderScreen._shareSelectedText: $e');
    }
  }

  /// Devuelve la página actual a su encuadre (cancela el zoom manual).
  void _resetPageZoom() {
    _pageZoomController.reset();
  }

  void _jumpToPage(int page) {
    if (page < 1) return;
    final maxPage = _pagesCount > 0 ? _pagesCount : page;
    final target = page > maxPage ? maxPage : page;
    _resetPageZoom();
    // No adelantar _currentPage: lo actualiza _onPageChanged al asentar la vista.
    if (_pageController.hasClients) {
      _pageController.jumpToPage(target - 1);
    } else {
      setState(() => _currentPage = target);
    }
    if (_sidebarVisible || _noteDismissed) {
      setState(() {
        _sidebarVisible = false;
        _noteDismissed = false;
      });
    }
  }

  Future<void> _toggleScrollMode() async {
    final next = _scrollMode == ReaderScrollMode.verticalContinuous
        ? ReaderScrollMode.horizontalPaged
        : ReaderScrollMode.verticalContinuous;
    final page = _currentPage;
    setState(() => _scrollMode = next);
    // Tras recrear la galería (Axis cambia con ValueKey), reasentar la página.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || _pagesCount < 1) return;
      final target = page.clamp(1, _pagesCount) - 1;
      if (_pageController.page?.round() != target) {
        _pageController.jumpToPage(target);
      }
    });
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
    if (_controlsVisible) {
      // Inmersivo: ocultar panel pero mantener herramienta (barra compacta / gestos).
      final annotations = _annotations;
      if (annotations != null && annotations.toolboxVisible) {
        if (annotations.activeTool != AnnotationTool.none) {
          _minimizeToolboxKeepingTool();
        } else {
          annotations.setToolboxVisible(false);
        }
      }
      _signing?.cancelPlacementMode();
    }
    setState(() => _controlsVisible = !_controlsVisible);
  }

  void _toggleSidebar() {
    setState(() => _sidebarVisible = !_sidebarVisible);
  }

  /// Misma secuencia para el botón ← y el Atrás del sistema.
  Future<void> _handleReaderBack() async {
    if (_signing?.exporting == true) {
      if (!mounted) return;
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
    if (_textSelecting) {
      _exitTextSelection();
      return;
    }
    if (_textSearching) {
      _exitTextSearch();
      return;
    }
    final annotations = _annotations;
    final toolboxVisible = annotations?.toolboxVisible ?? false;
    final activeTool = annotations?.activeTool ?? AnnotationTool.none;
    // Una sola pulsación: suelta la herramienta y cierra el panel.
    if (toolboxVisible || activeTool != AnnotationTool.none) {
      annotations?.clearTool();
      annotations?.setToolboxVisible(false);
      _resetPageZoom();
      setState(() {});
      return;
    }
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      return;
    }
    await _onExit();
  }

  void _minimizeToolboxKeepingTool() {
    final annotations = _annotations;
    if (annotations == null) return;
    annotations.minimizeToolbox();
    if (_didShowMinimizeHint || !mounted) return;
    if (annotations.activeTool == AnnotationTool.none) return;
    _didShowMinimizeHint = true;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.toolStillArmedHint),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 2200),
        ),
      );
  }

  Future<void> _undoAnnotation() async {
    final annotations = _annotations;
    if (annotations == null) return;
    final ok = await annotations.undo();
    if (!mounted) return;
    if (!ok && annotations.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_msg(annotations.error!))),
      );
    }
  }

  Future<void> _redoAnnotation() async {
    final annotations = _annotations;
    if (annotations == null) return;
    final ok = await annotations.redo();
    if (!mounted) return;
    if (!ok && annotations.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_msg(annotations.error!))),
      );
    }
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

  Future<void> _addBookmarkIfNeeded() async {
    final annotations = _annotations;
    if (annotations == null) return;
    if (annotations.isPageBookmarked(_currentPage)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pageAlreadyBookmarked),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
      return;
    }
    await _toggleBookmark();
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
    final annotations = _annotations;
    if (annotations == null) return;
    if (annotations.toolboxVisible) {
      // Con herramienta armada, cerrar = minimizar (sigue dibujando).
      if (annotations.activeTool != AnnotationTool.none) {
        _minimizeToolboxKeepingTool();
      } else {
        annotations.setToolboxVisible(false);
      }
    } else {
      annotations.setToolboxVisible(true);
    }
    setState(() {});
  }

  void _maybeShowReaderTip() {
    final prefs = _preferences;
    if (prefs == null || prefs.hasSeenReaderTip || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || prefs.hasSeenReaderTip) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.readerFirstTip),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      unawaited(prefs.markReaderTipSeen());
    });
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
      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.emptyNoteNotSaved),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(milliseconds: 1600),
            ),
          );
        return;
      }
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

    // Marcado/subrayado: solo háptica (evitar spam de SnackBars).
    // Chincheta/texto: confirmación breve.
    if (tool.needsText) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.annotationSaved(typeLabel, pageNumber)),
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      HapticFeedback.selectionClick();
    }
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
    _pageImageFutures.clear();
    if (opened != null) {
      try {
        await opened.dispose();
      } catch (_) {}
    }
  }

  Future<void> _reloadDocumentAfterOverwrite() async {
    if (!mounted) return;
    _documentGeneration++;
    await _openDocument();
    if (!mounted) return;
    final page = _currentPage;
    if (_pageController.hasClients && _pagesCount >= 1) {
      final target = page.clamp(1, _pagesCount);
      _pageController.jumpToPage(target - 1);
    }
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
        await _handleReaderBack();
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
                        ? (toolboxVisible
                            ? 200
                            : (activeTool != AnnotationTool.none
                                ? (activeTool.isMarkup && _pagesCount > 1
                                    ? 112
                                    : 72)
                                : 64))
                        : (activeTool != AnnotationTool.none ? 72 : 16),
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
                    hasNote: hasNote,
                    toolboxVisible: toolboxVisible,
                  ),
                // Banner de colocación siempre visible (también en modo inmersivo).
                if (signing?.placementMode == true && !toolboxVisible)
                  _buildPlacementBanner(),
                if (_controlsVisible &&
                    !toolboxVisible &&
                    !_textSelecting &&
                    !_textSearching &&
                    activeTool == AnnotationTool.none)
                  _buildBottomBar(
                    colors,
                    isBookmarked: isBookmarked,
                    signatureCount: pageSignatures.length,
                    annotationCount: pageAnnotations.length,
                  ),
                if (_textSelecting) _buildTextSelectionBar(colors),
                if (_textSearching) _buildTextSearchBar(colors),
                if (_controlsVisible && !_textSelecting && !_textSearching)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnnotationToolbox(
                      visible: toolboxVisible,
                      activeTool: activeTool,
                      navigationLocked: annotations?.navigationLocked ?? true,
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
                        _maybeFetchPageText();
                      },
                      onToggleNavigationLock: () {
                        annotations?.toggleNavigationLock();
                        if (annotations?.navigationLocked ?? true) {
                          _resetPageZoom();
                        }
                        setState(() {});
                      },
                      snapToText: annotations?.snapToText ?? true,
                      onToggleSnapToText: () {
                        annotations?.toggleSnapToText();
                        final value = annotations?.snapToText ?? true;
                        unawaited(
                          _preferences?.setSnapMarkupToText(value) ??
                              Future.value(),
                        );
                        setState(() {});
                        _maybeFetchPageText();
                      },
                      onInkColorChanged: (color) {
                        annotations?.setInkColor(color);
                        setState(() {});
                      },
                      onStrokeSizeChanged: (index) {
                        annotations?.setStrokeSizeIndex(index);
                        setState(() {});
                      },
                      onUndo: () => unawaited(_undoAnnotation()),
                      onRedo: () => unawaited(_redoAnnotation()),
                      onSave: () {
                        unawaited(_promptSaveAnnotations());
                      },
                      onClearTool: () {
                        annotations?.clearTool();
                        _resetPageZoom();
                      },
                      onClose: () {
                        if (activeTool != AnnotationTool.none) {
                          _minimizeToolboxKeepingTool();
                        } else {
                          annotations?.setToolboxVisible(false);
                        }
                      },
                    ),
                  ),
                // Barra compacta: visible también en modo inmersivo para poder deseleccionar.
                if (!toolboxVisible &&
                    !_textSelecting &&
                    activeTool != AnnotationTool.none)
                  _buildArmedToolStrip(
                    colors,
                    activeTool: activeTool,
                    navigationLocked: annotations?.navigationLocked ?? true,
                    snapToText: annotations?.snapToText ?? true,
                    canUndo: annotations?.canUndo ?? false,
                    onUndo: () => unawaited(_undoAnnotation()),
                    onToggleNavigationLock: () {
                      annotations?.toggleNavigationLock();
                      if (annotations?.navigationLocked ?? true) {
                        _resetPageZoom();
                      }
                      setState(() {});
                    },
                    onToggleSnapToText: () {
                      annotations?.toggleSnapToText();
                      final value = annotations?.snapToText ?? true;
                      unawaited(
                        _preferences?.setSnapMarkupToText(value) ??
                            Future.value(),
                      );
                      setState(() {});
                    },
                    onClear: () {
                      annotations?.clearTool();
                      _resetPageZoom();
                    },
                    onExpand: () {
                      if (!_controlsVisible) {
                        setState(() => _controlsVisible = true);
                      }
                      annotations?.setToolboxVisible(true);
                    },
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
                      icon: Icon(
                        Icons.fullscreen_exit,
                        color: colors.accent,
                      ),
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
                  onOpenAnnotationTools: () {
                    setState(() => _sidebarVisible = false);
                    if (!(annotations?.toolboxVisible ?? false)) {
                      _toggleAnnotationToolbox();
                    }
                  },
                  onStartSigning: () {
                    setState(() => _sidebarVisible = false);
                    _signDocument();
                  },
                  onAddBookmark: () {
                    setState(() => _sidebarVisible = false);
                    unawaited(_addBookmarkIfNeeded());
                  },
                  currentPageBookmarked: isBookmarked,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfView(AppPalette colors) {
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

    if (_openedDocument == null || _pagesCount < 1) {
      return Center(
        child: CircularProgressIndicator(color: colors.accent),
      );
    }

    final isVertical = _scrollMode.isVertical;
    final signing = _signing;
    final annotations = _annotations;
    final activeTool = annotations?.activeTool ?? AnnotationTool.none;
    final annotationsLayerEnabled =
        !(signing?.placementMode ?? false) && !_sidebarVisible;
    final navigationLocked = annotations?.navigationLocked ?? true;
    // Con Marcado/Subrayado el scroll de página SIEMPRE se bloquea:
    // un dedo dibuja; el candado abierto solo habilita zoom/pan con dos dedos.
    // El modo selección también bloquea el scroll para arrastrar el rectángulo.
    final drawingLocksScroll = activeTool.isMarkup || _textSelecting;
    final scaffoldBg =
        _ebonyFilter ? EbonyPdfFilter.background : colors.background;

    return PhotoViewGallery.builder(
      // Key por dirección de scroll: PageView no cambia Axis en caliente.
      key: ValueKey<String>('gallery-${_scrollMode.name}-$_documentGeneration'),
      pageController: _pageController,
      itemCount: _pagesCount,
      scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
      pageSnapping: !isVertical,
      scrollPhysics: drawingLocksScroll
          ? const NeverScrollableScrollPhysics()
          : (isVertical
              ? const BouncingScrollPhysics()
              : const PageScrollPhysics()),
      backgroundDecoration: BoxDecoration(color: scaffoldBg),
      onPageChanged: (index) => _onPageChanged(index + 1),
      loadingBuilder: (context, event) => Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.accent,
          ),
        ),
      ),
      builder: (context, index) {
        final pageNumber = index + 1;
        final pageSize = _pageSizes[pageNumber] ?? const Size(595, 842);
        // Con herramienta armada, TODAS las páginas visibles capturan el trazo.
        final pageTool =
            annotationsLayerEnabled && activeTool != AnnotationTool.none
                ? activeTool
                : AnnotationTool.none;
        final placementOnPage =
            (signing?.placementMode ?? false) && pageNumber == _currentPage;
        return PhotoViewGalleryPageOptions.customChild(
          child: SignedPdfPage(
            pageImageFuture: _pageImageFutureFor(pageNumber),
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
            navigationLocked: navigationLocked,
            zoomController: pageTool.isMarkup && pageNumber == _currentPage
                ? _pageZoomController
                : null,
            snapToText: annotations?.snapToText ?? false,
            textLines:
                pageNumber == _currentPage ? _currentPageLines : const [],
            textSelecting: _textSelecting && pageNumber == _currentPage,
            onTextSelected: (t) {
              if (_selectedText == t) return;
              setState(() => _selectedText = t);
            },
            searchHighlights: [
              for (final m in _searchMatches)
                if (m.pageNumber == pageNumber) m.rect,
            ],
            activeSearchHighlightIndex: () {
              if (_searchMatches.isEmpty) return null;
              if (_searchMatches[_searchMatchIndex].pageNumber != pageNumber) {
                return null;
              }
              var i = 0;
              for (var j = 0; j < _searchMatches.length; j++) {
                if (_searchMatches[j].pageNumber != pageNumber) continue;
                if (j == _searchMatchIndex) return i;
                i++;
              }
              return null;
            }(),
            ebonyFilter: _ebonyFilter,
            placementMode: placementOnPage,
            onPlaceTap: _openSignatureSheetAt,
            onCreateAnnotation: _createAnnotationRect,
            onOpenAnnotation: _openAnnotation,
            onDeleteAnnotation: _confirmDeleteAnnotation,
            signaturesInteractive: !(signing?.exporting ?? false) &&
                !(signing?.saving ?? false) &&
                !(signing?.loading ?? false) &&
                activeTool == AnnotationTool.none &&
                !(signing?.placementMode ?? false),
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
          childSize: pageSize,
          disableGestures: pageTool.isMarkup ||
              placementOnPage ||
              (_textSelecting && pageNumber == _currentPage),
          controller: pageTool.isMarkup && pageNumber == _currentPage
              ? _pageZoomController
              : null,
          initialScale: PhotoViewComputedScale.contained * 1.0,
          minScale: PhotoViewComputedScale.contained * 1.0,
          maxScale: PhotoViewComputedScale.contained * 3.0,
          heroAttributes: PhotoViewHeroAttributes(
            tag: 'pdf-$_documentGeneration-$index',
          ),
        );
      },
    );
  }

  Widget _buildTopBar(
    AppPalette colors,
    bool isBookmarked,
    DocumentSigningProvider? signing, {
    required bool hasNote,
    required bool toolboxVisible,
  }) {
    final l10n = AppLocalizations.of(context);
    final placement = signing?.placementMode == true;
    final activeTool = _annotations?.activeTool ?? AnnotationTool.none;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Pantallas estrechas: lápiz + ⋯; firma/scroll van al menú.
          final compact = constraints.maxWidth < 400;
          final penTooltip = toolboxVisible
              ? (activeTool != AnnotationTool.none
                  ? l10n.minimizeAnnotationTools
                  : l10n.closeAnnotationTools)
              : l10n.annotationTools;

          return Container(
            color: colors.panel.withValues(alpha: 0.94),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: placement ? l10n.cancelPlacement : l10n.back,
                  onPressed: () => unawaited(_handleReaderBack()),
                  icon: Icon(Icons.arrow_back, color: colors.text),
                ),
                IconButton(
                  tooltip: l10n.menuToc,
                  onPressed: _toggleSidebar,
                  icon: Icon(Icons.menu, color: colors.accent),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        _pagesCount > 0
                            ? '$_currentPage / $_pagesCount'
                            : '$_currentPage',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: penTooltip,
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
                if (!compact || placement)
                  IconButton(
                    tooltip:
                        placement ? l10n.cancelPlacement : l10n.signDocument,
                    onPressed: () {
                      if (placement) {
                        signing?.cancelPlacementMode();
                        setState(() {});
                        return;
                      }
                      _signDocument();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: placement
                          ? AppColors.ebonyAccent.withValues(alpha: 0.22)
                          : null,
                    ),
                    icon: Icon(
                      placement ? Icons.close : Icons.draw_outlined,
                      color: AppColors.ebonyAccent,
                    ),
                  ),
                if (!compact)
                  IconButton(
                    tooltip: l10n.scrollModeTooltip(
                      _scrollMode.localizedLabel(l10n),
                    ),
                    onPressed: _toggleScrollMode,
                    icon: Icon(
                      _scrollMode.isVertical
                          ? Icons.swap_vert
                          : Icons.swap_horiz,
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
                      case _ReaderToolAction.selectText:
                        _enterTextSelection();
                      case _ReaderToolAction.searchText:
                        _enterTextSearch();
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
                      case _ReaderToolAction.scrollMode:
                        unawaited(_toggleScrollMode());
                    }
                  },
                  itemBuilder: (context) {
                    final signBusy = signing?.saving == true ||
                        signing?.loading == true ||
                        signing?.exporting == true;
                    final annotationsBusy = _annotations?.savingToPdf == true;
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
                          label: hasNote ? l10n.editPageNote : l10n.addNote,
                          color: colors.accent,
                        ),
                      ),
                      PopupMenuItem(
                        value: _ReaderToolAction.selectText,
                        child: _ReaderToolMenuRow(
                          icon: Icons.text_fields,
                          label: l10n.selectTextTool,
                          color: AppColors.ebonyAccent,
                        ),
                      ),
                      PopupMenuItem(
                        value: _ReaderToolAction.searchText,
                        child: _ReaderToolMenuRow(
                          icon: Icons.search,
                          label: l10n.searchTextTool,
                          color: AppColors.ebonyAccent,
                        ),
                      ),
                      if (compact)
                        PopupMenuItem(
                          value: _ReaderToolAction.scrollMode,
                          child: _ReaderToolMenuRow(
                            icon: _scrollMode.isVertical
                                ? Icons.swap_vert
                                : Icons.swap_horiz,
                            label: l10n.scrollModeTooltip(
                              _scrollMode.localizedLabel(l10n),
                            ),
                            color: colors.accent,
                          ),
                        ),
                      if (compact && !placement)
                        PopupMenuItem(
                          value: _ReaderToolAction.sign,
                          enabled: !signBusy,
                          child: _ReaderToolMenuRow(
                            icon: Icons.draw_outlined,
                            label: l10n.signDocument,
                            color: AppColors.ebonyAccent,
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
                          color:
                              _ebonyFilter ? colors.accent : colors.textMuted,
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
                          icon: Icons.picture_as_pdf_outlined,
                          label: l10n.saveAnnotations,
                          color: saveAnnotationsEnabled
                              ? AppColors.ebonyAccent
                              : colors.textMuted,
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
          );
        },
      ),
    );
  }

  Widget _buildPlacementBanner() {
    final l10n = AppLocalizations.of(context);
    final canPrev = _currentPage > 1;
    final canNext = _pagesCount > 0 && _currentPage < _pagesCount;
    return Positioned(
      top: _controlsVisible ? 64 : 12,
      left: 12,
      right: 12,
      child: Material(
        color: AppColors.ebonyAccent.withValues(alpha: 0.95),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.touch_app, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.placementModeBanner,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _signing?.cancelPlacementMode();
                      setState(() {});
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(l10n.cancelPlacement),
                  ),
                ],
              ),
              if (_pagesCount > 1)
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.previousPage,
                      onPressed: canPrev
                          ? () => _jumpToPage(_currentPage - 1)
                          : null,
                      icon: Icon(
                        Icons.chevron_left,
                        color: canPrev
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$_currentPage / $_pagesCount',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.nextPage,
                      onPressed: canNext
                          ? () => _jumpToPage(_currentPage + 1)
                          : null,
                      icon: Icon(
                        Icons.chevron_right,
                        color: canNext
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra inferior del buscador de texto.
  Widget _buildTextSearchBar(AppPalette colors) {
    final l10n = AppLocalizations.of(context);
    final total = _searchMatches.length;
    final hasMatches = total > 0;
    final status = _searchBusy
        ? l10n.searchTextSearching
        : (_searchQuery.trim().isEmpty
            ? l10n.searchTextHint
            : (hasMatches
                ? l10n.searchTextMatchOf(_searchMatchIndex + 1, total)
                : l10n.searchTextNoResults));

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: colors.panel.withValues(alpha: 0.98),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.ebonyAccent.withValues(alpha: 0.45),
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.search,
                        size: 20, color: AppColors.ebonyAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchFieldController,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: _onSearchQueryChanged,
                        onSubmitted: (value) {
                          if (value.trim().isEmpty) return;
                          unawaited(_runTextSearch(value.trim()));
                        },
                        style: TextStyle(color: colors.text, fontSize: 15),
                        cursorColor: AppColors.ebonyAccent,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: l10n.searchTextHint,
                          hintStyle: TextStyle(color: colors.textMuted),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        tooltip: l10n.close,
                        onPressed: () {
                          _searchFieldController.clear();
                          _onSearchQueryChanged('');
                          _searchFocusNode.requestFocus();
                        },
                        icon: Icon(Icons.close, size: 18, color: colors.textMuted),
                      ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: hasMatches
                                  ? AppColors.ebonyAccent
                                  : colors.textMuted,
                              fontWeight: hasMatches
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.searchTextPrevious,
                      onPressed: hasMatches ? _goToPreviousSearchMatch : null,
                      icon: Icon(
                        Icons.keyboard_arrow_up,
                        color: hasMatches
                            ? AppColors.ebonyAccent
                            : colors.textMuted.withValues(alpha: 0.4),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.searchTextNext,
                      onPressed: hasMatches ? _goToNextSearchMatch : null,
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: hasMatches
                            ? AppColors.ebonyAccent
                            : colors.textMuted.withValues(alpha: 0.4),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.done,
                      onPressed: _exitTextSearch,
                      icon: const Icon(Icons.check,
                          size: 20, color: AppColors.ebonyAccent),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Barra inferior del modo selección de texto: copiar / compartir / cerrar.
  Widget _buildTextSelectionBar(AppPalette colors) {
    final l10n = AppLocalizations.of(context);
    final hasText = _selectedText.trim().isNotEmpty;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: colors.panel.withValues(alpha: 0.98),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.ebonyAccent.withValues(alpha: 0.45),
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.text_fields,
                    size: 18, color: AppColors.ebonyAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.selectTextTool,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.ebonyAccent,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        hasText
                            ? l10n.selectedCharacters(_selectedText.length)
                            : l10n.selectTextHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.copyText,
                  onPressed: hasText ? () => unawaited(_copySelectedText()) : null,
                  icon: Icon(
                    Icons.copy,
                    size: 20,
                    color: hasText
                        ? AppColors.ebonyAccent
                        : colors.textMuted.withValues(alpha: 0.4),
                  ),
                ),
                IconButton(
                  tooltip: l10n.shareDocument,
                  onPressed:
                      hasText ? () => unawaited(_shareSelectedText()) : null,
                  icon: Icon(
                    Icons.ios_share_outlined,
                    size: 20,
                    color: hasText
                        ? AppColors.ebonyAccent
                        : colors.textMuted.withValues(alpha: 0.4),
                  ),
                ),
                TextButton(
                  onPressed: _exitTextSelection,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textMuted,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(l10n.done),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Barra compacta cuando hay herramienta armada y el panel está minimizado.
  Widget _buildArmedToolStrip(
    AppPalette colors, {
    required AnnotationTool activeTool,
    required bool navigationLocked,
    required bool snapToText,
    required bool canUndo,
    required VoidCallback onUndo,
    required VoidCallback onToggleNavigationLock,
    required VoidCallback onToggleSnapToText,
    required VoidCallback onClear,
    required VoidCallback onExpand,
  }) {
    final l10n = AppLocalizations.of(context);
    final showLock = activeTool.isMarkup;
    // El scroll de página está bloqueado con cualquier markup armado.
    final showPageNav = activeTool.isMarkup && _pagesCount > 1;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: colors.panel.withValues(alpha: 0.96),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.ebonyAccent.withValues(alpha: 0.45),
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      activeTool.annotationType?.icon ?? Icons.border_color,
                      size: 18,
                      color: AppColors.ebonyAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeTool.label(l10n),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.ebonyAccent,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: onClear,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textMuted,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(l10n.releaseTool),
                    ),
                    IconButton(
                      tooltip: l10n.expandAnnotationTools,
                      onPressed: onExpand,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.unfold_more,
                        color: AppColors.ebonyAccent,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                if (showLock || canUndo || showPageNav) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (showLock) ...[
                        IconButton(
                          tooltip: snapToText
                              ? l10n.snapToTextOn
                              : l10n.snapToTextOff,
                          onPressed: onToggleSnapToText,
                          icon: Icon(
                            snapToText ? Icons.straighten : Icons.gesture,
                            size: 22,
                            color: snapToText
                                ? AppColors.ebonyAccent
                                : colors.textMuted,
                          ),
                        ),
                        IconButton(
                          tooltip: navigationLocked
                              ? l10n.unlockPageNavigation
                              : l10n.lockPageNavigation,
                          onPressed: onToggleNavigationLock,
                          icon: Icon(
                            navigationLocked ? Icons.lock : Icons.lock_open,
                            size: 22,
                            color: AppColors.ebonyAccent,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            navigationLocked
                                ? l10n.drawingLocksScrollHint
                                : l10n.drawingAllowsScrollHint,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      IconButton(
                        tooltip: l10n.annotationUndo,
                        onPressed: canUndo ? onUndo : null,
                        icon: Icon(
                          Icons.undo,
                          size: 22,
                          color: canUndo
                              ? AppColors.ebonyAccent
                              : colors.textMuted.withValues(alpha: 0.4),
                        ),
                      ),
                      if (showPageNav) ...[
                        IconButton(
                          tooltip: l10n.previousPage,
                          onPressed: _currentPage > 1
                              ? () => _jumpToPage(_currentPage - 1)
                              : null,
                          icon: Icon(
                            Icons.chevron_left,
                            color: _currentPage > 1
                                ? AppColors.ebonyAccent
                                : colors.textMuted.withValues(alpha: 0.35),
                          ),
                        ),
                        Text(
                          '$_currentPage/$_pagesCount',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: colors.accent),
                        ),
                        IconButton(
                          tooltip: l10n.nextPage,
                          onPressed: _currentPage < _pagesCount
                              ? () => _jumpToPage(_currentPage + 1)
                              : null,
                          icon: Icon(
                            Icons.chevron_right,
                            color: _currentPage < _pagesCount
                                ? AppColors.ebonyAccent
                                : colors.textMuted.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
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
  selectText,
  searchText,
  ebonyFilter,
  hideControls,
  share,
  saveAnnotations,
  sign,
  export,
  scrollMode,
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

