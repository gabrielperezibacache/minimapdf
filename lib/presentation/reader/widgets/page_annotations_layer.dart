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
/// Usa [Listener] para soportar S-Pen / lápices capacitivos con rechazo de
/// palma, muestreo del trazo y geometría de línea precisa.
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
    required AnnotationTool tool,
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
  final List<Offset> _path = <Offset>[];
  bool _creating = false;
  bool _panMoved = false;
  AnnotationTool? _gestureTool;
  int? _activePointer;
  int? _stylusPointer;

  bool get _captureGestures =>
      widget.enabled &&
      !_creating &&
      (widget.activeTool != AnnotationTool.none || _path.isNotEmpty);

  AnnotationTool get _effectiveTool => _gestureTool ?? widget.activeTool;

  Offset? get _dragStart => _path.isEmpty ? null : _path.first;
  Offset? get _dragCurrent => _path.isEmpty ? null : _path.last;

  @override
  void didUpdateWidget(covariant PageAnnotationsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTool != widget.activeTool &&
        _path.isEmpty &&
        !_creating) {
      _gestureTool = null;
    }
  }

  bool _isStylus(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;

  bool _acceptPointer(PointerEvent event) {
    if (!_captureGestures) return false;
    if (widget.activeTool == AnnotationTool.none && _path.isEmpty) {
      return false;
    }
    if (_stylusPointer != null &&
        event.pointer != _stylusPointer &&
        !_isStylus(event.kind)) {
      return false;
    }
    if (_activePointer != null && event.pointer != _activePointer) {
      return false;
    }
    if (event.kind == PointerDeviceKind.invertedStylus) {
      return false;
    }
    return true;
  }

  void _clearStroke() {
    _path.clear();
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
                      _path
                        ..clear()
                        ..add(event.localPosition);
                      _panMoved = false;
                      _activePointer = event.pointer;
                      if (stylus) _stylusPointer = event.pointer;
                    });
                  },
                  onPointerMove: (event) {
                    if (event.pointer != _activePointer || _path.isEmpty) {
                      return;
                    }
                    final last = _path.last;
                    final delta = (event.localPosition - last).distance;
                    // Muestrea el trazo sin saturar (cada ~1.5 px).
                    if (delta < 1.5 && _path.length > 1) return;
                    final moved =
                        (event.localPosition - _path.first).distance >
                            kDragCommitPx;
                    setState(() {
                      _path.add(event.localPosition);
                      if (moved) _panMoved = true;
                    });
                  },
                  onPointerUp: (event) async {
                    if (event.pointer != _activePointer) return;
                    final points = List<Offset>.from(_path);
                    if (points.isNotEmpty) {
                      if ((points.last - event.localPosition).distance > 0.5) {
                        points.add(event.localPosition);
                      } else {
                        points[points.length - 1] = event.localPosition;
                      }
                    }
                    final tool = _effectiveTool;
                    final wasStylus = _stylusPointer == event.pointer;
                    setState(() {
                      _clearStroke();
                      if (wasStylus) _stylusPointer = null;
                    });
                    if (points.isEmpty) return;
                    await _finishGesture(
                      size: size,
                      points: points,
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
            if (_panMoved && _dragStart != null && _dragCurrent != null)
              _DraftRect(
                points: List<Offset>.unmodifiable(_path),
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
    required List<Offset> points,
    AnnotationTool? toolOverride,
  }) async {
    if (_creating || size.width <= 0 || size.height <= 0 || points.isEmpty) {
      return;
    }
    final tool = toolOverride ?? widget.activeTool;
    if (tool == AnnotationTool.none) return;

    final MarkupRect? rect;
    if (tool.needsText) {
      rect = computePinRect(canvasSize: size, point: points.first);
    } else if (tool.isMarkup) {
      rect = computeMarkupRect(
        tool: tool,
        canvasSize: size,
        points: points,
      );
      // Gesto demasiado corto → no crear marca accidental.
      if (rect == null) return;
    } else {
      return;
    }

    if (!mounted) return;
    setState(() => _creating = true);
    try {
      HapticFeedback.selectionClick();
      await widget.onCreateRect(
        tool: tool,
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
    required this.points,
    required this.size,
    required this.tool,
  });

  final List<Offset> points;
  final Size size;
  final AnnotationTool tool;

  @override
  Widget build(BuildContext context) {
    if (!tool.isMarkup || points.isEmpty) return const SizedBox.shrink();

    final rect = computeMarkupRect(
      tool: tool,
      canvasSize: size,
      points: points,
    );
    if (rect == null) return const SizedBox.shrink();

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
                ? color.withValues(alpha: 0.55)
                : color.withValues(alpha: 0.9),
            borderRadius: tool == AnnotationTool.underline
                ? BorderRadius.circular(1)
                : BorderRadius.zero,
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
          ),
        ),
      AnnotationType.underline => DecoratedBox(
          decoration: BoxDecoration(
            color: annotation.color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      AnnotationType.note ||
      AnnotationType.comment ||
      AnnotationType.annotation =>
        _PinnedMark(annotation: annotation, colors: colors),
    };

    // Zona táctil mínima para subrayados finos.
    final hitHeight = annotation.type == AnnotationType.underline
        ? math.max(height, 14.0)
        : height;
    final hitTop = annotation.type == AnnotationType.underline
        ? top - (hitHeight - height) / 2
        : top;

    return Positioned(
      left: left,
      top: hitTop,
      width: width,
      height: hitHeight,
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
          child: annotation.type == AnnotationType.underline
              ? Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: child,
                  ),
                )
              : child,
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
