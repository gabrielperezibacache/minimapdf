import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_clamp.dart';
import '../../../data/models/page_annotation.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/reader_annotations_provider.dart';
import '../annotation_markup_geometry.dart';

/// Capa de dibujo/visualización de anotaciones sobre la página actual.
///
/// Usa [Listener] (no solo [GestureDetector]) para soportar S-Pen / lápices
/// capacitivos con rechazo de palma mientras el stylus está activo.
class PageAnnotationsLayer extends StatefulWidget {
  const PageAnnotationsLayer({
    super.key,
    required this.annotations,
    required this.activeTool,
    required this.enabled,
    required this.onCreateRect,
    required this.onOpenAnnotation,
    required this.onDeleteAnnotation,
  });

  final List<PageAnnotation> annotations;
  final AnnotationTool activeTool;
  final bool enabled;
  final Future<void> Function({
    required double x,
    required double y,
    required double width,
    required double height,
  }) onCreateRect;
  final ValueChanged<PageAnnotation> onOpenAnnotation;
  final ValueChanged<PageAnnotation> onDeleteAnnotation;

  @override
  State<PageAnnotationsLayer> createState() => _PageAnnotationsLayerState();
}

class _PageAnnotationsLayerState extends State<PageAnnotationsLayer> {
  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _creating = false;
  bool _panMoved = false;
  /// Herramienta fijada al iniciar el gesto (sobrevive al cambio de página).
  AnnotationTool? _gestureTool;
  /// Puntero activo del trazo (dedo, ratón o stylus).
  int? _activePointer;
  /// Stylus en contacto: se ignoran toques de palma.
  int? _stylusPointer;

  bool get _captureGestures =>
      widget.enabled &&
      !_creating &&
      (widget.activeTool != AnnotationTool.none || _dragStart != null);

  AnnotationTool get _effectiveTool => _gestureTool ?? widget.activeTool;

  @override
  void didUpdateWidget(covariant PageAnnotationsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No aborta un arrastre en curso si el tool de la página pasa a none.
    if (oldWidget.activeTool != widget.activeTool &&
        _dragStart == null &&
        !_creating) {
      _gestureTool = null;
    }
  }

  bool _isStylus(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;

  bool _acceptPointer(PointerEvent event) {
    if (!_captureGestures) return false;
    if (widget.activeTool == AnnotationTool.none && _dragStart == null) {
      return false;
    }
    // Rechazo de palma: con S-Pen abajo, ignorar dedos.
    if (_stylusPointer != null &&
        event.pointer != _stylusPointer &&
        !_isStylus(event.kind)) {
      return false;
    }
    // Un solo trazo a la vez.
    if (_activePointer != null && event.pointer != _activePointer) {
      return false;
    }
    // Punta borrador (invertedStylus): no dibuja.
    if (event.kind == PointerDeviceKind.invertedStylus) {
      return false;
    }
    return true;
  }

  void _clearStroke() {
    _dragStart = null;
    _dragCurrent = null;
    _panMoved = false;
    _gestureTool = null;
    _activePointer = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            for (final annotation in widget.annotations)
              _AnnotationMark(
                annotation: annotation,
                canvasSize: size,
                interactive: !_captureGestures,
                onTap: () => widget.onOpenAnnotation(annotation),
                onLongPress: () => widget.onDeleteAnnotation(annotation),
              ),
            if (_captureGestures)
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    if (!_acceptPointer(event)) return;
                    final stylus = _isStylus(event.kind);
                    setState(() {
                      _gestureTool = widget.activeTool;
                      _dragStart = event.localPosition;
                      _dragCurrent = event.localPosition;
                      _panMoved = false;
                      _activePointer = event.pointer;
                      if (stylus) _stylusPointer = event.pointer;
                    });
                  },
                  onPointerMove: (event) {
                    if (event.pointer != _activePointer || _dragStart == null) {
                      return;
                    }
                    final moved =
                        (event.localPosition - _dragStart!).distance >
                            kDragCommitPx;
                    setState(() {
                      _dragCurrent = event.localPosition;
                      if (moved) _panMoved = true;
                    });
                  },
                  onPointerUp: (event) async {
                    if (event.pointer != _activePointer) return;
                    final start = _dragStart;
                    final end = event.localPosition;
                    final moved = _panMoved;
                    final tool = _effectiveTool;
                    final wasStylus = _stylusPointer == event.pointer;
                    setState(() {
                      _clearStroke();
                      if (wasStylus) _stylusPointer = null;
                    });
                    if (start == null) return;
                    await _finishGesture(
                      size: size,
                      start: start,
                      end: end,
                      fromDrag: moved,
                      toolOverride: tool,
                    );
                  },
                  onPointerCancel: (event) {
                    if (event.pointer != _activePointer &&
                        event.pointer != _stylusPointer) {
                      return;
                    }
                    setState(() {
                      final wasStylus = _stylusPointer == event.pointer;
                      _clearStroke();
                      if (wasStylus) _stylusPointer = null;
                    });
                  },
                ),
              ),
            if (_dragStart != null && _dragCurrent != null && _panMoved)
              _DraftRect(
                start: _dragStart!,
                current: _dragCurrent!,
                size: size,
                tool: _effectiveTool,
              ),
          ],
        );
      },
    );
  }

  Future<void> _finishGesture({
    required Size size,
    required Offset start,
    required Offset end,
    required bool fromDrag,
    AnnotationTool? toolOverride,
  }) async {
    if (_creating || size.width <= 0 || size.height <= 0) return;
    final tool = toolOverride ?? widget.activeTool;
    if (tool == AnnotationTool.none) return;

    final MarkupRect rect;
    if (tool.needsText) {
      rect = computePinRect(canvasSize: size, point: start);
    } else if (tool.isMarkup) {
      rect = computeMarkupRect(
        tool: tool,
        canvasSize: size,
        start: start,
        end: end,
        fromDrag: fromDrag,
      );
    } else {
      return;
    }

    if (!mounted) return;
    setState(() => _creating = true);
    try {
      HapticFeedback.selectionClick();
      await widget.onCreateRect(
        x: rect.x,
        y: rect.y,
        width: rect.width,
        height: rect.height,
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

class _DraftRect extends StatelessWidget {
  const _DraftRect({
    required this.start,
    required this.current,
    required this.size,
    required this.tool,
  });

  final Offset start;
  final Offset current;
  final Size size;
  final AnnotationTool tool;

  @override
  Widget build(BuildContext context) {
    if (!tool.isMarkup) return const SizedBox.shrink();

    final rect = computeMarkupRect(
      tool: tool,
      canvasSize: size,
      start: start,
      end: current,
      fromDrag: true,
    );

    final left = rect.x * size.width;
    final top = rect.y * size.height;
    final width = safeClamp(rect.width * size.width, 2.0, size.width);
    final height = safeClamp(rect.height * size.height, 2.0, size.height);
    final color = tool.annotationType?.defaultColor ?? AppColors.ebonyAccent;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tool == AnnotationTool.highlight
                ? color
                : color.withValues(alpha: 0.35),
            border: Border.all(
              color: AppColors.ebonyAccent.withValues(alpha: 0.85),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnotationMark extends StatelessWidget {
  const _AnnotationMark({
    required this.annotation,
    required this.canvasSize,
    required this.interactive,
    required this.onTap,
    required this.onLongPress,
  });

  final PageAnnotation annotation;
  final Size canvasSize;
  final bool interactive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final left = annotation.x * canvasSize.width;
    final top = annotation.y * canvasSize.height;
    final width = safeClamp(
      annotation.width * canvasSize.width,
      1.0,
      canvasSize.width.isFinite ? canvasSize.width : 1.0,
    );
    final height = safeClamp(
      annotation.height * canvasSize.height,
      1.0,
      canvasSize.height.isFinite ? canvasSize.height : 1.0,
    );

    final child = switch (annotation.type) {
      AnnotationType.highlight => DecoratedBox(
          decoration: BoxDecoration(
            color: annotation.color,
            border: Border.all(
              color: AppColors.ebonyAccent.withValues(alpha: 0.35),
            ),
          ),
        ),
      AnnotationType.underline => Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: math.max(2.0, height * 0.55).clamp(2.0, 4.0),
            decoration: BoxDecoration(
              color: annotation.color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      AnnotationType.note ||
      AnnotationType.comment ||
      AnnotationType.annotation =>
        _PinnedMark(annotation: annotation, colors: colors),
    };

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Semantics(
        button: interactive,
        label: '${annotation.type.label(AppLocalizations.of(context))}'
            '${annotation.hasText ? ': ${annotation.text}' : ''}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: interactive ? onTap : null,
          onLongPress: interactive
              ? () {
                  HapticFeedback.mediumImpact();
                  onLongPress();
                }
              : null,
          child: child,
        ),
      ),
    );
  }
}

class _PinnedMark extends StatelessWidget {
  const _PinnedMark({
    required this.annotation,
    required this.colors,
  });

  final PageAnnotation annotation;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: colors.panel.withValues(alpha: 0.95),
          border: Border.all(color: AppColors.ebonyAccent, width: 1.5),
        ),
        child: Icon(
          annotation.type.icon,
          size: 16,
          color: AppColors.ebonyAccent,
        ),
      ),
    );
  }
}
