import 'dart:ui' show Offset, Size;

import '../providers/reader_annotations_provider.dart';
import 'annotation_ink.dart';

export 'annotation_ink.dart' show MarkupRect;

/// Compatibilidad: arrastre mínimo (px) para confirmar marcado/subrayado.
const double kDragCommitPx = kStrokeCommitPx;

MarkupRect _clampToPage(MarkupRect rect) {
  var w = rect.width.clamp(0.01, 1.0);
  var h = rect.height.clamp(0.006, 1.0);
  var x = rect.x;
  var y = rect.y;
  if (x < 0) x = 0;
  if (y < 0) y = 0;
  if (x + w > 1) x = 1 - w;
  if (y + h > 1) y = 1 - h;
  if (x < 0) {
    x = 0;
    w = w.clamp(0.01, 1.0);
  }
  if (y < 0) {
    y = 0;
    h = h.clamp(0.006, 1.0);
  }
  return MarkupRect(x: x, y: y, width: w, height: h);
}

/// Calcula el bounding box del trazo a mano alzada (estilo Samsung Notes).
///
/// El path se guarda aparte en `ink_json`; este rect solo sirve para hit-test
/// y compatibilidad con filas antiguas. Devuelve `null` si el gesto es corto.
MarkupRect? computeMarkupRect({
  required AnnotationTool tool,
  required Size canvasSize,
  required List<Offset> points,
}) {
  assert(tool.isMarkup);
  final stroke = normalizePixelStroke(
    canvasSize: canvasSize,
    points: points,
  );
  if (stroke == null) return null;
  return boundingRectForStroke(
    canvasSize: canvasSize,
    stroke: stroke,
    strokeWidthPx: strokeWidthPxForTool(tool),
  );
}

/// Rectángulo de pin para nota/comentario (toque).
MarkupRect computePinRect({
  required Size canvasSize,
  required Offset point,
}) {
  const width = 0.1;
  const height = 0.055;
  final w = canvasSize.width <= 0 ? 1.0 : canvasSize.width;
  final h = canvasSize.height <= 0 ? 1.0 : canvasSize.height;
  return _clampToPage(
    MarkupRect(
      x: (point.dx / w) - (width / 2),
      y: (point.dy / h) - (height / 2),
      width: width,
      height: height,
    ),
  );
}

/// API de compatibilidad: start/end (+ fromDrag) → path de dos puntos.
MarkupRect? computeMarkupRectFromEndpoints({
  required AnnotationTool tool,
  required Size canvasSize,
  required Offset start,
  required Offset end,
  required bool fromDrag,
}) {
  if (!fromDrag && start == end) return null;
  return computeMarkupRect(
    tool: tool,
    canvasSize: canvasSize,
    points: [start, end],
  );
}
