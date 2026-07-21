import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart' show PhotoViewController;

import '../../../data/models/page_annotation.dart';
import '../../../domain/pdf_text_service.dart';
import '../../providers/reader_annotations_provider.dart';
import '../eager_gesture_capture.dart';
import '../photo_view_page_rect.dart';
import '../text_line_snap.dart';
import 'page_annotations_layer.dart';
import 'text_selection_layer.dart';

/// Captura gestos en todo el viewport y los proyecta sobre la página visible.
///
/// Las capas interactivas dentro de PhotoView solo cubren el rectángulo de la
/// página; los márgenes (letterbox) y el pan dejan zonas muertas. Este widget
/// evita que herramientas y selección de texto fallen en esos bordes.
class ReaderViewportCapture extends StatefulWidget {
  const ReaderViewportCapture({
    super.key,
    required this.viewportSize,
    required this.pageSize,
    required this.zoomController,
    required this.activeTool,
    required this.annotations,
    required this.annotationsEnabled,
    required this.inkColor,
    required this.strokeWidthPx,
    required this.navigationLocked,
    required this.snapToText,
    required this.textBands,
    required this.onCreateRect,
    required this.onOpenAnnotation,
    required this.onDeleteAnnotation,
    required this.textSelecting,
    required this.textLines,
    required this.onTextSelected,
    required this.placementMode,
    this.onPlaceTap,
  });

  final Size viewportSize;
  final Size pageSize;
  final PhotoViewController zoomController;
  final AnnotationTool activeTool;
  final List<PageAnnotation> annotations;
  final bool annotationsEnabled;
  final Color? inkColor;
  final double? strokeWidthPx;
  final bool navigationLocked;
  final bool snapToText;
  final List<TextBand> textBands;
  final Future<void> Function({
    required AnnotationTool tool,
    required double x,
    required double y,
    required double width,
    required double height,
    List<List<List<double>>>? strokes,
  }) onCreateRect;
  final ValueChanged<PageAnnotation> onOpenAnnotation;
  final ValueChanged<PageAnnotation> onDeleteAnnotation;
  final bool textSelecting;
  final List<PdfLineBox> textLines;
  final ValueChanged<String> onTextSelected;
  final bool placementMode;
  final void Function(double x, double y)? onPlaceTap;

  @override
  State<ReaderViewportCapture> createState() => _ReaderViewportCaptureState();
}

class _ReaderViewportCaptureState extends State<ReaderViewportCapture> {
  final GlobalKey<PageAnnotationsLayerState> _annotationsKey =
      GlobalKey<PageAnnotationsLayerState>();
  final GlobalKey<TextSelectionLayerState> _selectionKey =
      GlobalKey<TextSelectionLayerState>();

  bool get _toolActive =>
      widget.annotationsEnabled && widget.activeTool != AnnotationTool.none;

  bool get _capturing =>
      _toolActive || widget.textSelecting || widget.placementMode;

  Rect _pageRect() {
    return photoViewPageRectInViewport(
      viewportSize: widget.viewportSize,
      pageSize: widget.pageSize,
      controllerValue: widget.zoomController.value,
    );
  }

  Offset _pageLocal(Offset viewportPoint, Rect pageRect) {
    return viewportPointToPageLocal(viewportPoint, pageRect);
  }

  void _handlePlacement(PointerDownEvent event, Rect pageRect) {
    final onPlace = widget.onPlaceTap;
    if (!widget.placementMode || onPlace == null) return;
    final local = _pageLocal(event.localPosition, pageRect);
    final x = (local.dx / pageRect.width).clamp(0.0, 1.0);
    final y = (local.dy / pageRect.height).clamp(0.0, 1.0);
    onPlace(x, y);
  }

  @override
  Widget build(BuildContext context) {
    if (!_capturing) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: widget.zoomController,
      builder: (context, _) {
        final pageRect = _pageRect();
        if (pageRect.width <= 0 || pageRect.height <= 0) {
          return const SizedBox.shrink();
        }

        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: eagerCaptureGestures(debugOwner: this),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              final local = _pageLocal(event.localPosition, pageRect);
              if (widget.textSelecting) {
                _selectionKey.currentState
                    ?.handlePointerDown(event, localOverride: local);
                return;
              }
              if (_toolActive) {
                _annotationsKey.currentState
                    ?.handlePointerDown(event, localOverride: local);
                return;
              }
              if (widget.placementMode) {
                _handlePlacement(event, pageRect);
              }
            },
            onPointerMove: (event) {
              final local = _pageLocal(event.localPosition, pageRect);
              if (widget.textSelecting) {
                _selectionKey.currentState
                    ?.handlePointerMove(event, localOverride: local);
                return;
              }
              if (_toolActive) {
                _annotationsKey.currentState
                    ?.handlePointerMove(event, localOverride: local);
              }
            },
            onPointerUp: (event) {
              final local = _pageLocal(event.localPosition, pageRect);
              if (widget.textSelecting) {
                _selectionKey.currentState
                    ?.handlePointerUp(event, localOverride: local);
                return;
              }
              if (_toolActive) {
                _annotationsKey.currentState
                    ?.handlePointerUp(event, localOverride: local);
              }
            },
            onPointerCancel: (event) {
              final local = _pageLocal(event.localPosition, pageRect);
              if (widget.textSelecting) {
                _selectionKey.currentState
                    ?.handlePointerCancel(event, localOverride: local);
                return;
              }
              if (_toolActive) {
                _annotationsKey.currentState
                    ?.handlePointerCancel(event, localOverride: local);
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (_toolActive)
                  Positioned.fromRect(
                    rect: pageRect,
                    child: PageAnnotationsLayer(
                      key: _annotationsKey,
                      annotations: widget.annotations,
                      activeTool: widget.activeTool,
                      enabled: widget.annotationsEnabled,
                      inkColor: widget.inkColor,
                      strokeWidthPx: widget.strokeWidthPx,
                      navigationLocked: widget.navigationLocked,
                      zoomController: widget.zoomController,
                      snapToText: widget.snapToText,
                      textBands: widget.textBands,
                      externalPointerRouting: true,
                      onCreateRect: widget.onCreateRect,
                      onOpenAnnotation: widget.onOpenAnnotation,
                      onDeleteAnnotation: widget.onDeleteAnnotation,
                    ),
                  ),
                if (widget.textSelecting)
                  Positioned.fromRect(
                    rect: pageRect,
                    child: TextSelectionLayer(
                      key: _selectionKey,
                      lines: widget.textLines,
                      externalPointerRouting: true,
                      onSelectionChanged: widget.onTextSelected,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
