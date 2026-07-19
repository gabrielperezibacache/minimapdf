import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

import '../../core/preferences/app_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/hermes_pdf_filter.dart';
import '../../data/datasources/library_local_datasource.dart';
import '../../data/models/book.dart';
import '../../data/models/bookmark.dart';
import '../providers/reader_annotations_provider.dart';
import 'reader_scroll_mode.dart';
import 'reading_progress_saver.dart';
import 'widgets/floating_page_note.dart';
import 'widgets/note_edit_sheet.dart';
import 'widgets/reader_sidebar.dart';

/// Lector PDF de alto rendimiento (pdfx) con filtro Hermes Obsidian.
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

  ReaderScrollMode _scrollMode = ReaderScrollMode.verticalContinuous;
  bool _obsidianFilter = true;
  bool _controlsVisible = true;
  bool _sidebarVisible = false;
  bool _noteDismissed = false;
  int _pagesCount = 0;
  int _currentPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final initialPage = math.max(1, widget.book.lastPageRead);
    _currentPage = initialPage;

    _controller = PdfController(
      document: PdfDocument.openFile(widget.book.filePath),
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
        _obsidianFilter = prefs.obsidianFilter;
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
      if (bookId != null) {
        annotations.loadForBook(bookId);
      }
      annotations.addListener(_onAnnotationsChanged);
    }
  }

  void _onAnnotationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _annotations?.removeListener(_onAnnotationsChanged);
    _annotations?.dispose();
    // El guardado fiable ocurre en _onExit / lifecycle; aquí best-effort.
    final saver = _progressSaver;
    if (saver != null) {
      if (saver.currentPage != _currentPage) {
        saver.onPageChanged(_currentPage);
      }
      unawaited(saver.saveIfNeeded());
      saver.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Evita escrituras redundantes en blips iOS (inactive/hidden frecuentes).
    if (state == AppLifecycleState.paused) {
      final saver = _progressSaver;
      if (saver == null) return;
      if (saver.currentPage != _currentPage) {
        saver.onPageChanged(_currentPage);
      }
      unawaited(saver.saveIfNeeded());
    }
  }

  Future<void> _onExit() async {
    final saver = _progressSaver;
    if (saver != null) {
      if (saver.currentPage != _currentPage) {
        saver.onPageChanged(_currentPage);
      }
      await saver.saveIfNeeded();
    }
    if (!mounted) return;
    Navigator.of(context).pop(_currentPage);
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    _progressSaver?.onPageChanged(page);
    _noteDismissed = false;
    if (mounted) setState(() {});
  }

  void _jumpToPage(int page) {
    if (page < 1) return;
    _controller.jumpToPage(page);
    setState(() {
      _currentPage = page;
      _sidebarVisible = false;
      _noteDismissed = false;
    });
  }

  Future<void> _toggleScrollMode() async {
    final next = _scrollMode == ReaderScrollMode.verticalContinuous
        ? ReaderScrollMode.horizontalPaged
        : ReaderScrollMode.verticalContinuous;
    setState(() => _scrollMode = next);
    await _preferences?.setScrollModeName(next.name);
  }

  Future<void> _toggleFilter() async {
    final next = !_obsidianFilter;
    setState(() => _obsidianFilter = next);
    await _preferences?.setObsidianFilter(next);
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

    final completed = await annotations.toggleBookmark(_currentPage);
    if (completed || !mounted) {
      if (annotations.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(annotations.error!)),
        );
      }
      return;
    }

    final colors = HermesColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.panel,
        title: const Text('Quitar marcador'),
        content: const Text(
          'Esta página tiene una nota. ¿Eliminar marcador y nota?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await annotations.toggleBookmark(_currentPage, force: true);
      if (annotations.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(annotations.error!)),
        );
      }
    }
  }

  Future<void> _editNote() async {
    final annotations = _annotations;
    final existing = annotations?.bookmarkForPage(_currentPage);
    final result = await showNoteEditSheet(
      context,
      pageNumber: _currentPage,
      initialText: existing?.noteText,
    );
    if (result == null || !mounted || annotations == null) return;
    await annotations.saveNote(pageNumber: _currentPage, noteText: result);
    if (!mounted) return;
    if (annotations.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(annotations.error!)),
      );
      return;
    }
    setState(() => _noteDismissed = false);
  }

  Future<void> _deleteBookmark(Bookmark bookmark) async {
    final annotations = _annotations;
    if (annotations == null) return;

    final hasNote =
        bookmark.noteText != null && bookmark.noteText!.trim().isNotEmpty;
    if (hasNote) {
      final colors = HermesColors.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: colors.panel,
          title: const Text('Eliminar marcador'),
          content: Text(
            '¿Eliminar el marcador de la página ${bookmark.pageNumber} '
            'y su nota?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Eliminar', style: TextStyle(color: colors.accent)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await annotations.deleteBookmark(bookmark);
    if (annotations.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(annotations.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);
    final scaffoldBg =
        _obsidianFilter ? HermesPdfFilter.background : colors.background;
    final annotations = _annotations;
    final currentBookmark = annotations?.bookmarkForPage(_currentPage);
    final noteText = currentBookmark?.noteText;
    final hasNote = noteText != null && noteText.isNotEmpty;
    final isBookmarked = currentBookmark != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_sidebarVisible) {
          setState(() => _sidebarVisible = false);
          return;
        }
        await _onExit();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _obsidianFilter
            ? SystemUiOverlayStyle.light
            : (Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark),
        child: Scaffold(
          backgroundColor: scaffoldBg,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: HermesPdfFilter.wrap(
                    enabled: _obsidianFilter,
                    child: _buildPdfView(colors),
                  ),
                ),
                if (hasNote && !_noteDismissed)
                  Positioned(
                    right: 12,
                    bottom: _controlsVisible ? 64 : 16,
                    child: FloatingPageNote(
                      noteText: noteText,
                      pageNumber: _currentPage,
                      onEdit: _editNote,
                      onDismiss: () => setState(() => _noteDismissed = true),
                    ),
                  ),
                if (_controlsVisible) _buildTopBar(colors, isBookmarked),
                if (_controlsVisible) _buildBottomBar(colors, isBookmarked),
                if (!_controlsVisible)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: 'Mostrar controles',
                      onPressed: _toggleControls,
                      style: IconButton.styleFrom(
                        backgroundColor: colors.panel.withValues(alpha: 0.85),
                      ),
                      icon: Icon(Icons.more_horiz, color: colors.accent),
                    ),
                  ),
                ReaderSidebar(
                  visible: _sidebarVisible,
                  pagesCount: _pagesCount,
                  currentPage: _currentPage,
                  bookmarks: annotations?.bookmarks ?? const [],
                  onClose: () => setState(() => _sidebarVisible = false),
                  onOpenPage: _jumpToPage,
                  onDeleteBookmark: _deleteBookmark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfView(HermesColors colors) {
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

    return PdfView(
      key: ValueKey(_scrollMode),
      controller: _controller,
      scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
      pageSnapping: !isVertical,
      physics: isVertical
          ? const BouncingScrollPhysics()
          : const PageScrollPhysics(),
      backgroundDecoration: BoxDecoration(
        color: _obsidianFilter ? HermesPdfFilter.background : colors.background,
      ),
      onPageChanged: _onPageChanged,
      onDocumentLoaded: (document) {
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
      },
      onDocumentError: (error) {
        setState(() => _error = 'No se pudo abrir el PDF.\n$error');
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
            'Error al cargar la página',
            style: TextStyle(color: colors.text),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(HermesColors colors, bool isBookmarked) {
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
              tooltip: 'Menú / índice',
              onPressed: _toggleSidebar,
              icon: Icon(Icons.menu, color: colors.accent),
            ),
            IconButton(
              tooltip: 'Volver',
              onPressed: _onExit,
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
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip:
                          isBookmarked ? 'Quitar marcador' : 'Marcar página',
                      onPressed: _toggleBookmark,
                      icon: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: colors.accent,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Añadir nota',
                      onPressed: _editNote,
                      icon: Icon(
                        Icons.sticky_note_2_outlined,
                        color: colors.accent,
                      ),
                    ),
                    IconButton(
                      tooltip: _obsidianFilter
                          ? 'Desactivar filtro Obsidian'
                          : 'Filtro Hermes Obsidian',
                      onPressed: _toggleFilter,
                      icon: Icon(
                        _obsidianFilter
                            ? Icons.dark_mode
                            : Icons.dark_mode_outlined,
                        color:
                            _obsidianFilter ? colors.accent : colors.textMuted,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Modo: ${_scrollMode.label}',
                      onPressed: _toggleScrollMode,
                      icon: Icon(
                        _scrollMode.isVertical
                            ? Icons.swap_vert
                            : Icons.swap_horiz,
                        color: colors.accent,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ocultar controles',
                      onPressed: _toggleControls,
                      icon: Icon(Icons.fullscreen, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(HermesColors colors, bool isBookmarked) {
    final label =
        _pagesCount > 0 ? '$_currentPage / $_pagesCount' : '$_currentPage';

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: colors.panel.withValues(alpha: 0.94),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (isBookmarked) ...[
              Icon(Icons.bookmark, size: 16, color: colors.accent),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.accent,
                  ),
            ),
            const Spacer(),
            Text(
              _scrollMode.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_obsidianFilter) ...[
              const SizedBox(width: 12),
              Text(
                'Obsidian',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.accent,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
