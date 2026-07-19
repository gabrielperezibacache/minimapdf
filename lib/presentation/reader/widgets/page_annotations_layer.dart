import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/page_annotation.dart';
import '../../providers/reader_annotations_provider.dart';

/// Capa de dibujo/visualización de anotaciones sobre la página actual.
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

  bool get _captureGestures =>
      widget.enabled &&
      !_creating &&
      widget.activeTool != AnnotationTool.none;

  @override
  void didUpdateWidget(covariant PageAnnotationsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTool != widget.activeTool) {
      _dragStart = null;
      _dragCurrent = null;
      _panMoved = false;
    }
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Tap: imprescindible para notas/comentarios (pan no recibe toques).
                  onTapUp: (details) async {
                    if (_dragStart != null) return;
                    await _finishGesture(
                      size: size,
                      start: details.localPosition,
                      end: details.localPosition,
                    );
                  },
                  onPanStart: (details) {
                    setState(() {
                      _dragStart = details.localPosition;
                      _dragCurrent = details.localPosition;
                      _panMoved = false;
                    });
                  },
                  onPanUpdate: (details) {
                    if (_dragStart == null) return;
                    final moved =
                        (details.localPosition - _dragStart!).distance > 8;
                    setState(() {
                      _dragCurrent = details.localPosition;
                      if (moved) _panMoved = true;
                    });
                  },
                  onPanEnd: (_) async {
                    final start = _dragStart;
                    final end = _dragCurrent ?? start;
                    final moved = _panMoved;
                    setState(() {
                      _dragStart = null;
                      _dragCurrent = null;
                      _panMoved = false;
                    });
                    // Solo arrastres reales: los toques los resuelve onTapUp.
                    if (!moved || start == null || end == null) return;
                    await _finishGesture(size: size, start: start, end: end);
                  },

                  onPanCancel: () {
                    setState(() {
                      _dragStart = null;
                      _dragCurrent = null;
                      _panMoved = false;
                    });
                  },
                ),
              ),
            if (_dragStart != null && _dragCurrent != null && _panMoved)
              _DraftRect(
                start: _dragStart!,
                current: _dragCurrent!,
                size: size,
                tool: widget.activeTool,
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
  }) async {
    if (_creating || size.width <= 0 || size.height <= 0) return;
    if (widget.activeTool == AnnotationTool.none) return;

    final dx = (end.dx - start.dx).abs();
    final dy = (end.dy - start.dy).abs();
    final isTap = dx < 12 && dy < 12;
    final tool = widget.activeTool;

    late double left;
    late double top;
    late double width;
    late double height;

    if (tool.needsText) {
      width = 0.1;
      height = 0.055;
      left = (start.dx / size.width) - (width / 2);
      top = (start.dy / size.height) - (height / 2);
    } else if (isTap) {
      width = 0.34;
      height = tool == AnnotationTool.underline ? 0.016 : 0.045;
      left = (start.dx / size.width) - 0.02;
      top = (start.dy / size.height) - (height / 2);
    } else {
      left = (start.dx < end.dx ? start.dx : end.dx) / size.width;
      top = (start.dy < end.dy ? start.dy : end.dy) / size.height;
      width = (dx / size.width).clamp(0.04, 1.0);
      height = (dy / size.height).clamp(0.012, 1.0);
      if (tool == AnnotationTool.underline) {
        top = top + height - 0.014;
        height = 0.014;
      } else if (tool == AnnotationTool.highlight && height < 0.028) {
        height = 0.028;
      }
    }

    setState(() => _creating = true);
    try {
      HapticFeedback.selectionClick();
      await widget.onCreateRect(x: left, y: top, width: width, height: height);
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
    final left = start.dx < current.dx ? start.dx : current.dx;
    final top = start.dy < current.dy ? start.dy : current.dy;
    final width = (current.dx - start.dx).abs().clamp(4.0, size.width);
    var height = (current.dy - start.dy).abs().clamp(3.0, size.height);
    var drawTop = top;
    if (tool == AnnotationTool.underline) {
      drawTop = top + height - 3;
      height = 3;
    }

    final color = tool.annotationType?.defaultColor ?? AppColors.obsidianAccent;

    return Positioned(
      left: left,
      top: drawTop,
      width: width,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tool == AnnotationTool.highlight
                ? color
                : color.withValues(alpha: 0.35),
            border: Border.all(
              color: AppColors.obsidianAccent.withValues(alpha: 0.85),
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
    final colors = HermesColors.of(context);
    final left = annotation.x * canvasSize.width;
    final top = annotation.y * canvasSize.height;
    final width =
        (annotation.width * canvasSize.width).clamp(10.0, canvasSize.width);
    final height =
        (annotation.height * canvasSize.height).clamp(6.0, canvasSize.height);

    final child = switch (annotation.type) {
      AnnotationType.highlight => DecoratedBox(
          decoration: BoxDecoration(
            color: annotation.color,
            border: Border.all(
              color: AppColors.obsidianAccent.withValues(alpha: 0.35),
            ),
          ),
        ),
      AnnotationType.underline => Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 3,
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
        label: '${annotation.type.label}'
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
  final HermesColors colors;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: colors.panel.withValues(alpha: 0.95),
          border: Border.all(color: AppColors.obsidianAccent, width: 1.5),
        ),
        child: Icon(
          annotation.type.icon,
          size: 16,
          color: AppColors.obsidianAccent,
        ),
      ),
    );
  }
}
