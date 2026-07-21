import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart' show PhotoViewController;

import '../../../core/theme/app_colors.dart';
import '../text_line_snap.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_clamp.dart';
import '../../../data/models/page_annotation.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/reader_annotations_provider.dart';
import '../../signing/ink_stroke_painter.dart';
import '../annotation_ink.dart';
import '../annotation_markup_geometry.dart';
import '../eager_gesture_capture.dart';

/// Preview del trazo sin reconstruir el widget en cada move.
class _DraftStrokeListenable extends ChangeNotifier {
  final List<Offset> points = <Offset>[];
  bool moved = false;

  void begin(Offset point) {
    points
      ..clear()
      ..add(point);
    moved = false;
    notifyListeners();
  }

  void append(Offset point, {required bool markMoved}) {
    points.add(point);
    if (markMoved && !moved) {
      moved = true;
    }
    notifyListeners();
  }

  void clear() {
    if (points.isEmpty && !moved) return;
    points.clear();
    moved = false;
    notifyListeners();
  }
}

/// Capa de dibujo/visualización de anotaciones sobre la página.
///
/// Marcado y subrayado son trazos a mano alzada (estilo Samsung Notes):
/// el path se pinta tal cual, sin redimensionar a cajas de texto.
class PageAnnotationsLayer extends StatefulWidget {
  const PageAnnotationsLayer({
    super.key,
    required this.annotations,
    required this.activeTool,
    required this.enabled,
    required this.onCreateRect,
    required this.onOpenAnnotation,
    required this.onDeleteAnnotation,
    this.inkColor,
    this.strokeWidthPx,
    this.navigationLocked = true,
    this.zoomController,
    this.snapToText = false,
    this.textBands = const [],
    this.externalPointerRouting = false,
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
    List<List<List<double>>>? strokes,
  }) onCreateRect;
  final ValueChanged<PageAnnotation> onOpenAnnotation;
  final ValueChanged<PageAnnotation> onDeleteAnnotation;
  final Color? inkColor;
  final double? strokeWidthPx;
  /// Candado cerrado: un dedo dibuja, sin zoom. Abierto: un dedo dibuja y
  /// dos dedos hacen zoom/pan sobre [zoomController].
  final bool navigationLocked;
  /// Controlador de PhotoView de la página actual (solo para zoom con 2 dedos).
  final PhotoViewController? zoomController;
  /// Imantar marcado/subrayado a las líneas de texto detectadas.
  final bool snapToText;
  /// Bandas de texto de la página (normalizadas 0–1), para el imantado.
  final List<TextBand> textBands;
  /// Si true, no instala [Listener] propio; el padre enruta punteros vía
  /// [PageAnnotationsLayerState.handlePointer*].
  final bool externalPointerRouting;

  @override
  State<PageAnnotationsLayer> createState() => PageAnnotationsLayerState();
}

class PageAnnotationsLayerState extends State<PageAnnotationsLayer> {
  final _DraftStrokeListenable _draft = _DraftStrokeListenable();
  bool _creating = false;
  AnnotationTool? _gestureTool;
  int? _activePointer;
  PointerDeviceKind? _activeKind;
  int? _stylusPointer;
  /// Bandas congeladas al inicio del trazo (evita saltos si llegan tarde).
  List<TextBand> _strokeBands = const [];

  /// Punteros de dedo activos (global position) para el zoom con dos dedos.
  final Map<int, Offset> _touchPositions = <int, Offset>{};
  bool _zooming = false;
  double _zoomBaseScale = 0; // escala en reposo (contained) capturada perezosa.
  double _zoomScaleStart = 0;
  double _zoomDistStart = 0;
  Offset _zoomNormalized = Offset.zero;

  bool get _captureGestures =>
      widget.enabled &&
      (widget.activeTool != AnnotationTool.none || _draft.points.isNotEmpty);

  AnnotationTool get _effectiveTool => _gestureTool ?? widget.activeTool;

  Color get _draftColor {
    final custom = widget.inkColor;
    if (custom != null) return custom;
    return (_effectiveTool.annotationType?.defaultColor ?? AppColors.ebonyAccent)
        .withValues(
      alpha: _effectiveTool == AnnotationTool.highlight ? 0.55 : 0.95,
    );
  }

  double get _draftStrokeWidth =>
      widget.strokeWidthPx ?? strokeWidthPxForTool(_effectiveTool);

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PageAnnotationsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.activeTool != widget.activeTool ||
            oldWidget.enabled != widget.enabled) &&
        _draft.points.isEmpty &&
        !_creating) {
      _gestureTool = null;
      _activePointer = null;
      _activeKind = null;
      _stylusPointer = null;
    }
  }

  bool _isStylus(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;

  bool _isDrawablePointer(PointerEvent event) {
    if (event.kind == PointerDeviceKind.invertedStylus) return false;
    return event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.mouse;
  }

  void _beginStroke(PointerEvent event, Offset localPosition) {
    final stylus = _isStylus(event.kind);
    _gestureTool = widget.activeTool;
    _activePointer = event.pointer;
    _activeKind = event.kind;
    _stylusPointer = stylus ? event.pointer : null;
    // Congela bandas al primer toque para un imantado estable.
    _strokeBands = List<TextBand>.of(widget.textBands);
    // Sin setState: evita reconstruir el recognizer a mitad del gesto.
    _draft.begin(localPosition);
  }

  /// Enrutado de punteros desde una capa de viewport (márgenes incluidos).
  void handlePointerDown(PointerDownEvent event, {Offset? localOverride}) {
    _onPointerDown(event, localOverride ?? event.localPosition, _layoutSize);
  }

  void handlePointerMove(PointerMoveEvent event, {Offset? localOverride}) {
    _onPointerMove(event, localOverride ?? event.localPosition, _layoutSize);
  }

  void handlePointerUp(PointerUpEvent event, {Offset? localOverride}) {
    _onPointerUp(event, localOverride ?? event.localPosition, _layoutSize);
  }

  void handlePointerCancel(PointerCancelEvent event, {Offset? localOverride}) {
    _onPointerCancel(event, localOverride ?? event.localPosition, _layoutSize);
  }

  Size _layoutSize = Size.zero;

  bool _acceptPointerDown(PointerEvent event) {
    if (!_captureGestures) return false;
    if (widget.activeTool == AnnotationTool.none && _draft.points.isEmpty) {
      return false;
    }
    if (!_isDrawablePointer(event)) return false;

    final stylus = _isStylus(event.kind);

    // S-Pen tiene prioridad sobre palma/dedo ya activo.
    if (stylus &&
        _activePointer != null &&
        _activePointer != event.pointer &&
        _activeKind != PointerDeviceKind.stylus) {
      return true;
    }

    // Con S-Pen activo, ignorar toques de palma.
    if (_stylusPointer != null && event.pointer != _stylusPointer && !stylus) {
      return false;
    }

    if (_activePointer != null && event.pointer != _activePointer) {
      return false;
    }
    return true;
  }

  void _clearStrokePointers() {
    _gestureTool = null;
    _activePointer = null;
    _activeKind = null;
    _stylusPointer = null;
  }

  void _abortDraftForNavigation() {
    _clearStrokePointers();
    _draft.clear();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _layoutSize = size;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            // Marcas debajo de la captura: con herramienta armada no roban el
            // primer toque (nota/marcado/subrayado).
            for (final annotation in widget.annotations)
              _AnnotationMark(
                annotation: annotation,
                canvasSize: size,
                interactive: !_captureGestures,
                onTap: () => widget.onOpenAnnotation(annotation),
                onLongPress: () => widget.onDeleteAnnotation(annotation),
              ),
            if (_captureGestures && !widget.externalPointerRouting)
              Positioned.fill(child: _buildCaptureSurface(size)),
            Positioned.fill(
              child: ListenableBuilder(
                listenable: _draft,
                builder: (context, _) {
                  if (!_draft.moved || _draft.points.length < 2) {
                    return const SizedBox.shrink();
                  }
                  return IgnorePointer(
                    child: CustomPaint(
                      painter: InkStrokePainter(
                        strokes: [
                          [
                            for (final p in _draft.points) [p.dx, p.dy],
                          ],
                        ],
                        color: _draftColor,
                        strokeWidth: _draftStrokeWidth,
                        normalized: false,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Superficie de captura: [Listener] + recognizers eager para ganar al
  /// PageView/PhotoView desde el primer toque.
  ///
  /// - 1 dedo o S-Pen: dibuja (sin arena lenta).
  /// - Candado abierto + 2 dedos: zoom/pan del PDF vía [zoomController].
  Widget _buildCaptureSurface(Size size) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: eagerCaptureGestures(debugOwner: this),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => _onPointerDown(event, event.localPosition, size),
        onPointerMove: (event) => _onPointerMove(event, event.localPosition, size),
        onPointerUp: (event) => _onPointerUp(event, event.localPosition, size),
        onPointerCancel: (event) =>
            _onPointerCancel(event, event.localPosition, size),
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event, Offset localPosition, Size size) {
    _layoutSize = size;
    final stylus = _isStylus(event.kind);
    if (!stylus) {
      _touchPositions[event.pointer] = event.position;
    }

    // Candado abierto: al llegar el 2º dedo entramos en zoom/pan.
    // Sin zoomController (páginas no actuales) no abortar el trazo.
    if (!widget.navigationLocked && !stylus && _touchPositions.length >= 2) {
      if (widget.zoomController == null) return;
      _abortDraftForNavigation();
      _beginZoom();
      return;
    }
    if (_zooming) return;

    if (!_acceptPointerDown(event)) return;

    if (stylus &&
        _activePointer != null &&
        _activePointer != event.pointer) {
      _beginStroke(event, localPosition);
      return;
    }
    if (_activePointer != null && event.pointer != _activePointer) {
      return;
    }
    _beginStroke(event, localPosition);
  }

  void _onPointerMove(PointerMoveEvent event, Offset localPosition, Size size) {
    _layoutSize = size;
    if (!_isStylus(event.kind)) {
      _touchPositions[event.pointer] = event.position;
    }
    if (_zooming) {
      _updateZoom();
      return;
    }
    if (event.pointer != _activePointer || _draft.points.isEmpty) {
      return;
    }
    final last = _draft.points.last;
    final delta = (localPosition - last).distance;
    if (delta < kStrokeSamplePx && _draft.points.length > 1) return;
    final moved =
        (localPosition - _draft.points.first).distance > kStrokeCommitPx;
    _draft.append(localPosition, markMoved: moved);
  }

  void _onPointerUp(PointerUpEvent event, Offset localPosition, Size size) {
    _layoutSize = size;
    _touchPositions.remove(event.pointer);
    if (_zooming) {
      _maybeEndZoom();
      return;
    }
    if (event.pointer != _activePointer) return;
    unawaited(_completeStroke(localPosition, size));
  }

  void _onPointerCancel(
    PointerCancelEvent event,
    Offset localPosition,
    Size size,
  ) {
    _layoutSize = size;
    _touchPositions.remove(event.pointer);
    if (_zooming) {
      _maybeEndZoom();
      return;
    }
    if (event.pointer != _activePointer && event.pointer != _stylusPointer) {
      return;
    }
    // Si el sistema canceló un trazo válido, guardarlo igual.
    final points = List<Offset>.from(_draft.points);
    final tool = _effectiveTool;
    _clearStrokePointers();
    _draft.clear();
    if (tool.isMarkup && isStrokeCommitWorthy(points)) {
      unawaited(
        _finishGesture(
          size: size,
          points: points,
          toolOverride: tool,
        ),
      );
    }
  }

  // ── Zoom/pan con dos dedos (candado abierto) ────────────────────────────

  List<Offset> get _twoTouches {
    final list = _touchPositions.values.toList(growable: false);
    return list.length >= 2 ? [list[0], list[1]] : const [];
  }

  void _beginZoom() {
    final controller = widget.zoomController;
    final touches = _twoTouches;
    if (controller == null || touches.length < 2) return;
    final scale = controller.scale;
    if (scale == null) return; // PhotoView aún no calculó la escala base.
    if (_zoomBaseScale <= 0) _zoomBaseScale = scale;

    _zooming = true;
    _zoomScaleStart = scale;
    _zoomDistStart = (touches[0] - touches[1]).distance;
    if (_zoomDistStart <= 0) _zoomDistStart = 1;
    final focalStart = (touches[0] + touches[1]) / 2;
    _zoomNormalized = focalStart - controller.position;
  }

  void _updateZoom() {
    final controller = widget.zoomController;
    final touches = _twoTouches;
    if (controller == null || touches.length < 2 || _zoomBaseScale <= 0) return;
    final distNow = (touches[0] - touches[1]).distance;
    final factor = distNow / _zoomDistStart;
    final newScale = (_zoomScaleStart * factor)
        .clamp(_zoomBaseScale, _zoomBaseScale * 3.0);
    final focalNow = (touches[0] + touches[1]) / 2;
    final posFactor = newScale / _zoomScaleStart;
    final newPosition = (focalNow - _zoomNormalized) * posFactor;
    controller.updateMultiple(scale: newScale, position: newPosition);
  }

  void _maybeEndZoom() {
    if (_touchPositions.length >= 2) {
      // Aún quedan dos dedos: recalcular base para un gesto continuo.
      _beginZoom();
      return;
    }
    _zooming = false;
  }

  Future<void> _completeStroke(Offset lastPoint, Size size) async {
    final points = List<Offset>.from(_draft.points);
    if (points.isNotEmpty) {
      if ((points.last - lastPoint).distance > 0.5) {
        points.add(lastPoint);
      } else {
        points[points.length - 1] = lastPoint;
      }
    }
    final tool = _effectiveTool;
    _clearStrokePointers();
    _draft.clear();
    if (points.isEmpty) return;
    await _finishGesture(
      size: size,
      points: points,
      toolOverride: tool,
    );
  }

  Future<void> _finishGesture({
    required Size size,
    required List<Offset> points,
    AnnotationTool? toolOverride,
  }) async {
    if (size.width <= 0 || size.height <= 0 || points.isEmpty) {
      return;
    }
    // No descartar el trazo si el anterior aún se está guardando.
    while (_creating) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
    }
    final tool = toolOverride ?? widget.activeTool;
    if (tool == AnnotationTool.none) return;

    MarkupRect? rect;
    List<List<List<double>>>? strokes;

    if (tool.needsText) {
      rect = computePinRect(canvasSize: size, point: points.first);
    } else if (tool.isMarkup) {
      final stroke = normalizePixelStroke(canvasSize: size, points: points);
      if (stroke == null) {
        if (!mounted) return;
        HapticFeedback.lightImpact();
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).strokeTooShortHint),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(milliseconds: 1600),
            ),
          );
        return;
      }
      // Imantado: ajusta el trazo a las bandas congeladas al inicio del gesto.
      var finalStroke = stroke;
      if (widget.snapToText) {
        final underline = tool == AnnotationTool.underline;
        final bands =
            _strokeBands.isNotEmpty ? _strokeBands : widget.textBands;
        finalStroke = snapStrokeToBands(
              stroke: stroke,
              bands: bands,
              underline: underline,
            ) ??
            straightenStroke(stroke: stroke, underline: underline);
      }
      final strokeWidth =
          widget.strokeWidthPx ?? strokeWidthPxForTool(tool);
      rect = boundingRectForStroke(
        canvasSize: size,
        stroke: finalStroke,
        strokeWidthPx: strokeWidth,
      );
      if (rect == null) return;
      strokes = [finalStroke];
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
        strokes: strokes,
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
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

    if (annotation.type.isMarkup && annotation.hasInk) {
      return Positioned.fill(
        child: _InkMarkupHitTarget(
          annotation: annotation,
          canvasSize: canvasSize,
          interactive: interactive,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      );
    }

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
      child: IgnorePointer(
        ignoring: !interactive,
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
      ),
    );
  }
}

class _InkMarkupHitTarget extends StatelessWidget {
  const _InkMarkupHitTarget({
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
    final left = annotation.x * canvasSize.width;
    final top = annotation.y * canvasSize.height;
    final width = safeClamp(
      annotation.width * canvasSize.width,
      8.0,
      canvasSize.width.isFinite ? canvasSize.width : 8.0,
    );
    final height = safeClamp(
      annotation.height * canvasSize.height,
      8.0,
      canvasSize.height.isFinite ? canvasSize.height : 8.0,
    );
    final strokePx = annotation.effectiveStrokeWidth;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: CustomPaint(
            painter: InkStrokePainter(
              strokes: annotation.inkStrokes,
              color: annotation.color,
              strokeWidth: strokePx,
              normalized: true,
            ),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: IgnorePointer(
            ignoring: !interactive,
            child: Semantics(
              button: interactive,
              label: annotation.type.label(AppLocalizations.of(context)),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: interactive ? onTap : null,
                onLongPress: interactive
                    ? () {
                        HapticFeedback.mediumImpact();
                        onLongPress();
                      }
                    : null,
              ),
            ),
          ),
        ),
      ],
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
