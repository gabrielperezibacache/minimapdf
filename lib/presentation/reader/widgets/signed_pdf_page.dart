import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart' show PhotoViewController;

import '../../../core/theme/ebony_pdf_filter.dart';
import '../../../data/models/document_signature.dart';
import '../../../data/models/page_annotation.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/pdf_text_service.dart';
import '../../providers/reader_annotations_provider.dart';
import '../../signing/signature_overlay.dart';
import '../annotation_ink.dart' show MarkupRect;
import '../pdf_text_selection.dart';
import '../text_line_snap.dart';
import 'page_annotations_layer.dart';
import 'text_search_highlight_layer.dart';
import 'text_selection_layer.dart';

/// Página PDF con sellos de firma y anotaciones anclados al rectángulo de la página.
///
/// El filtro Ébano se aplica solo a la imagen, no a los sellos ni anotaciones.
/// El tamaño del widget usa [fallbackSize] (puntos PDF) para coincidir con
/// PhotoView `childSize` y con la geometría de exportación.
///
/// La imagen se cachea por [pageNumber] para evitar recopiar bytes en cada
/// rebuild del lector (anotaciones / firmas / chrome).
class SignedPdfPage extends StatefulWidget {
  const SignedPdfPage({
    super.key,
    required this.pageImageFuture,
    required this.pageNumber,
    required this.signatures,
    required this.ebonyFilter,
    required this.placementMode,
    required this.onPlaceTap,
    required this.onMove,
    required this.onDelete,
    this.signaturesInteractive = true,
    this.annotations = const [],
    this.activeTool = AnnotationTool.none,
    this.annotationsEnabled = true,
    this.documentGeneration = 0,
    this.inkColor,
    this.strokeWidthPx,
    this.navigationLocked = true,
    this.zoomController,
    this.snapToText = false,
    this.textLines = const [],
    this.textSelecting = false,
    this.onTextSelected,
    this.searchHighlights = const [],
    this.activeSearchHighlightIndex,
    this.onCreateAnnotation,
    this.onOpenAnnotation,
    this.onDeleteAnnotation,
    this.fallbackSize = const Size(595, 842),
  });

  /// PNG rasterizado de la página (pdfrx).
  final Future<Uint8List> pageImageFuture;
  final int pageNumber;
  final List<DocumentSignature> signatures;
  final bool ebonyFilter;
  final bool placementMode;
  final void Function(int pageNumber, double x, double y) onPlaceTap;
  final Future<bool> Function(
    DocumentSignature signature,
    double x,
    double y,
  ) onMove;
  final ValueChanged<DocumentSignature> onDelete;
  /// Si false, no se pueden arrastrar/borrar firmas (export/carga).
  final bool signaturesInteractive;
  final List<PageAnnotation> annotations;
  final AnnotationTool activeTool;
  final bool annotationsEnabled;
  /// Invalida la caché de imagen al reemplazar el PDF en disco.
  final int documentGeneration;
  final Color? inkColor;
  final double? strokeWidthPx;
  /// Candado de navegación (scroll/zoom) con herramienta armada.
  final bool navigationLocked;
  /// Controlador de zoom de PhotoView (solo página actual, candado abierto).
  final PhotoViewController? zoomController;
  /// Imantar marcado/subrayado a las líneas de texto de la página.
  final bool snapToText;
  /// Líneas de texto reales del PDF (capa de texto) para esta página.
  final List<PdfLineBox> textLines;
  /// Modo selección de texto activo (solo página actual).
  final bool textSelecting;
  final ValueChanged<String>? onTextSelected;
  /// Resaltados de búsqueda en esta página (coords normalizadas).
  final List<MarkupRect> searchHighlights;
  /// Índice del resaltado activo dentro de [searchHighlights].
  final int? activeSearchHighlightIndex;
  final Future<void> Function({
    required int pageNumber,
    required AnnotationTool tool,
    required double x,
    required double y,
    required double width,
    required double height,
    List<List<List<double>>>? strokes,
  })? onCreateAnnotation;
  final ValueChanged<PageAnnotation>? onOpenAnnotation;
  final ValueChanged<PageAnnotation>? onDeleteAnnotation;
  final Size fallbackSize;

  @override
  State<SignedPdfPage> createState() => _SignedPdfPageState();
}

class _SignedPdfPageState extends State<SignedPdfPage> {
  Uint8List? _cachedBytes;
  int? _cachedPageNumber;
  Object? _loadError;
  Future<Uint8List>? _boundFuture;

  List<TextBand> _textBands = const [];
  int? _bandsPage;
  int _bandsGeneration = -1;
  bool _detectingBands = false;

  @override
  void initState() {
    super.initState();
    _bindFuture(widget.pageImageFuture, widget.pageNumber);
  }

  @override
  void didUpdateWidget(covariant SignedPdfPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.documentGeneration != widget.documentGeneration) {
      _cachedBytes = null;
      _cachedPageNumber = null;
      _loadError = null;
      _textBands = const [];
      _bandsPage = null;
      _bindFuture(widget.pageImageFuture, widget.pageNumber);
      return;
    }
    // Misma página: si ya hay bytes, ignorar futuros nuevos del gallery rebuild.
    if (_cachedBytes != null && _cachedPageNumber == widget.pageNumber) {
      return;
    }
    if (!identical(_boundFuture, widget.pageImageFuture)) {
      _bindFuture(widget.pageImageFuture, widget.pageNumber);
    }
  }

  void _bindFuture(Future<Uint8List> future, int pageNumber) {
    _boundFuture = future;
    future.then((bytes) {
      if (!mounted || pageNumber != widget.pageNumber) return;
      if (!identical(_boundFuture, future)) return;
      setState(() {
        _cachedBytes = bytes;
        _cachedPageNumber = pageNumber;
        _loadError = null;
      });
    }).catchError((Object error) {
      if (!mounted || pageNumber != widget.pageNumber) return;
      if (!identical(_boundFuture, future)) return;
      setState(() => _loadError = error);
    });
  }

  /// Bandas efectivas para el imantado: líneas reales del PDF o, si no hay
  /// capa de texto (escaneado), la proyección de tinta como respaldo.
  List<TextBand> get _effectiveBands {
    if (widget.textLines.isNotEmpty) return bandsFromLines(widget.textLines);
    return _textBands;
  }

  /// Detecta líneas de texto (una vez por página) para imantar el marcado.
  void _maybeDetectBands(Uint8List bytes) {
    if (widget.textLines.isNotEmpty) return; // ya hay texto real
    if (_detectingBands) return;
    final upToDate = _bandsPage == widget.pageNumber &&
        _bandsGeneration == widget.documentGeneration;
    if (upToDate) return;
    _detectingBands = true;
    final page = widget.pageNumber;
    final generation = widget.documentGeneration;
    () async {
      List<TextBand> bands = const [];
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        bands = await detectTextBandsFromImage(frame.image);
        frame.image.dispose();
      } catch (_) {
        bands = const [];
      }
      if (!mounted) return;
      if (page != widget.pageNumber ||
          generation != widget.documentGeneration) {
        _detectingBands = false;
        return;
      }
      setState(() {
        _textBands = bands;
        _bandsPage = page;
        _bandsGeneration = generation;
        _detectingBands = false;
      });
    }();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null && _cachedBytes == null) {
      return SizedBox.fromSize(
        size: widget.fallbackSize,
        child: Center(
          child: Text(AppLocalizations.of(context).pageLoadError),
        ),
      );
    }

    final bytes = _cachedBytes;
    if (bytes == null) {
      return SizedBox.fromSize(
        size: widget.fallbackSize,
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (widget.snapToText && widget.activeTool.isMarkup) {
      _maybeDetectBands(bytes);
    }

    return SizedBox(
      width: widget.fallbackSize.width,
      height: widget.fallbackSize.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          EbonyPdfFilter.wrap(
            enabled: widget.ebonyFilter,
            child: Image.memory(
              bytes,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          ),
          // Con herramienta de dibujo: anotaciones encima de firmas para que
          // el Material de los sellos no robe el dedo/S-Pen.
          if (widget.activeTool != AnnotationTool.none &&
              !widget.placementMode) ...[
            IgnorePointer(
              ignoring: true,
              child: SignatureLayer(
                signatures: widget.signatures,
                topReserve: 0,
                bottomReserve: 0,
                placementMode: false,
                signaturesInteractive: false,
                onPlaceTap: null,
                onMove: widget.onMove,
                onDelete: widget.onDelete,
              ),
            ),
            if (widget.onCreateAnnotation != null &&
                widget.onOpenAnnotation != null &&
                widget.onDeleteAnnotation != null)
              PageAnnotationsLayer(
                annotations: widget.annotations,
                activeTool: widget.activeTool,
                enabled: widget.annotationsEnabled && !widget.placementMode,
                inkColor: widget.inkColor,
                strokeWidthPx: widget.strokeWidthPx,
                navigationLocked: widget.navigationLocked,
                zoomController: widget.zoomController,
                snapToText: widget.snapToText,
                textBands: _effectiveBands,
                onCreateRect: ({
                  required AnnotationTool tool,
                  required double x,
                  required double y,
                  required double width,
                  required double height,
                  List<List<List<double>>>? strokes,
                }) {
                  return widget.onCreateAnnotation!(
                    pageNumber: widget.pageNumber,
                    tool: tool,
                    x: x,
                    y: y,
                    width: width,
                    height: height,
                    strokes: strokes,
                  );
                },
                onOpenAnnotation: widget.onOpenAnnotation!,
                onDeleteAnnotation: widget.onDeleteAnnotation!,
              ),
          ] else ...[
            if (widget.onCreateAnnotation != null &&
                widget.onOpenAnnotation != null &&
                widget.onDeleteAnnotation != null)
              IgnorePointer(
                ignoring: widget.textSelecting,
                child: PageAnnotationsLayer(
                  annotations: widget.annotations,
                  activeTool: widget.activeTool,
                  enabled: widget.annotationsEnabled &&
                      !widget.placementMode &&
                      !widget.textSelecting,
                  inkColor: widget.inkColor,
                  strokeWidthPx: widget.strokeWidthPx,
                  navigationLocked: widget.navigationLocked,
                  snapToText: widget.snapToText,
                  textBands: _effectiveBands,
                  onCreateRect: ({
                    required AnnotationTool tool,
                    required double x,
                    required double y,
                    required double width,
                    required double height,
                    List<List<List<double>>>? strokes,
                  }) {
                    return widget.onCreateAnnotation!(
                      pageNumber: widget.pageNumber,
                      tool: tool,
                      x: x,
                      y: y,
                      width: width,
                      height: height,
                      strokes: strokes,
                    );
                  },
                  onOpenAnnotation: widget.onOpenAnnotation!,
                  onDeleteAnnotation: widget.onDeleteAnnotation!,
                ),
              ),
            IgnorePointer(
              ignoring: widget.textSelecting,
              child: SignatureLayer(
                signatures: widget.signatures,
                topReserve: 0,
                bottomReserve: 0,
                placementMode: widget.placementMode,
                signaturesInteractive: widget.signaturesInteractive &&
                    !widget.textSelecting,
                onPlaceTap: (x, y) =>
                    widget.onPlaceTap(widget.pageNumber, x, y),
                onMove: widget.onMove,
                onDelete: widget.onDelete,
              ),
            ),
          ],
          if (widget.searchHighlights.isNotEmpty)
            Positioned.fill(
              child: TextSearchHighlightLayer(
                highlights: widget.searchHighlights,
                activeIndex: widget.activeSearchHighlightIndex,
              ),
            ),
          if (widget.textSelecting && widget.onTextSelected != null)
            Positioned.fill(
              child: TextSelectionLayer(
                lines: widget.textLines,
                onSelectionChanged: widget.onTextSelected!,
              ),
            ),
        ],
      ),
    );
  }
}
