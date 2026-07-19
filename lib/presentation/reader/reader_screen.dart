import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/hermes_pdf_filter.dart';
import '../../data/datasources/library_local_datasource.dart';
import '../../data/models/book.dart';
import 'reader_scroll_mode.dart';
import 'reading_progress_saver.dart';

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

  ReaderScrollMode _scrollMode = ReaderScrollMode.verticalContinuous;
  bool _obsidianFilter = true;
  bool _controlsVisible = true;
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
    if (_progressSaver != null) return;

    final saver = ReadingProgressSaver(
      context.read<LibraryLocalDatasource>(),
    );
    final bookId = widget.book.id;
    if (bookId != null) {
      saver.attach(bookId: bookId, initialPage: _currentPage);
    }
    _progressSaver = saver;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressSaver?.saveNow(page: _currentPage);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _progressSaver?.saveNow(page: _currentPage);
    }
  }

  Future<void> _onExit() async {
    await _progressSaver?.saveNow(page: _currentPage);
    if (!mounted) return;
    Navigator.of(context).pop(_currentPage);
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    _progressSaver?.onPageChanged(page);
    if (mounted) setState(() {});
  }

  void _toggleScrollMode() {
    setState(() {
      _scrollMode = _scrollMode == ReaderScrollMode.verticalContinuous
          ? ReaderScrollMode.horizontalPaged
          : ReaderScrollMode.verticalContinuous;
    });
  }

  void _toggleFilter() {
    setState(() => _obsidianFilter = !_obsidianFilter);
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);
    final scaffoldBg =
        _obsidianFilter ? HermesPdfFilter.background : colors.background;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
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
                if (_controlsVisible) _buildTopBar(colors),
                if (_controlsVisible) _buildBottomBar(colors),
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
        setState(() {
          _pagesCount = document.pagesCount;
          _error = null;
        });
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

  Widget _buildTopBar(HermesColors colors) {
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
            IconButton(
              tooltip: _obsidianFilter
                  ? 'Desactivar filtro Obsidian'
                  : 'Filtro Hermes Obsidian',
              onPressed: _toggleFilter,
              icon: Icon(
                _obsidianFilter ? Icons.dark_mode : Icons.dark_mode_outlined,
                color: _obsidianFilter ? colors.accent : colors.textMuted,
              ),
            ),
            IconButton(
              tooltip: 'Modo: ${_scrollMode.label}',
              onPressed: _toggleScrollMode,
              icon: Icon(
                _scrollMode.isVertical ? Icons.swap_vert : Icons.swap_horiz,
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
    );
  }

  Widget _buildBottomBar(HermesColors colors) {
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
