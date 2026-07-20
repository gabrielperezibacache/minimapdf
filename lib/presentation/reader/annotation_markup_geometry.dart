import 'dart:ui' show Offset, Size;

import '../providers/reader_annotations_provider.dart';

/// Rectángulo normalizado (0–1) sobre la página PDF.
class MarkupRect {
  const MarkupRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Altura visual de una línea de texto en píxeles de canvas (aprox.).
const double kMarkupLineHeightPx = 18.0;
const double kUnderlineStrokePx = 3.0;
/// Arrastre mínimo (px) para confirmar marcado/subrayado.
const double kDragCommitPx = 6.0;
/// Ancho mínimo del trazo en fracción de página.
const double kMinMarkupWidth = 0.01;
/// Si ΔY del trazo supera esto × altura de línea → caja multilínea.
const double kMultiLineFactor = 1.75;

double _lineHeightNorm(Size canvas) {
  if (canvas.height <= 0) return 0.022;
  return (kMarkupLineHeightPx / canvas.height).clamp(0.014, 0.04);
}

double _underlineHeightNorm(Size canvas) {
  if (canvas.height <= 0) return 0.008;
  return (kUnderlineStrokePx / canvas.height).clamp(0.004, 0.016);
}

double _pathLength(List<Offset> points) {
  if (points.length < 2) return 0;
  var len = 0.0;
  for (var i = 1; i < points.length; i++) {
    len += (points[i] - points[i - 1]).distance;
  }
  return len;
}

/// Media de Y del trazo (estable ante temblores).
double _meanY(List<Offset> points) {
  var sum = 0.0;
  for (final p in points) {
    sum += p.dy;
  }
  return sum / points.length;
}

MarkupRect _clampToPage(MarkupRect rect) {
  var w = rect.width.clamp(kMinMarkupWidth, 1.0);
  var h = rect.height.clamp(0.004, 1.0);
  var x = rect.x;
  var y = rect.y;
  if (x < 0) x = 0;
  if (y < 0) y = 0;
  if (x + w > 1) x = 1 - w;
  if (y + h > 1) y = 1 - h;
  if (x < 0) {
    x = 0;
    w = w.clamp(kMinMarkupWidth, 1.0);
  }
  if (y < 0) {
    y = 0;
    h = h.clamp(0.004, 1.0);
  }
  return MarkupRect(x: x, y: y, width: w, height: h);
}

/// Calcula el rectángulo de marcado/subrayado a partir del trazo.
///
/// Devuelve `null` si el gesto es demasiado corto (evita marcas accidentales
/// por toque). El arrastre horizontal se ancla a la línea del trazo; un ΔY
/// grande produce una caja multilínea (solo en marcado).
MarkupRect? computeMarkupRect({
  required AnnotationTool tool,
  required Size canvasSize,
  required List<Offset> points,
}) {
  assert(tool.isMarkup);
  if (points.isEmpty) return null;

  final w = canvasSize.width;
  final h = canvasSize.height;
  if (w <= 0 || h <= 0) return null;

  final start = points.first;
  final end = points.last;
  final spanX = (end.dx - start.dx).abs();
  // Envergadura del path (incluye zigzags), no solo start→end.
  final travel = _pathLength(points);
  final commit = travel >= kDragCommitPx || spanX >= kDragCommitPx;
  if (!commit) return null;

  var minX = start.dx;
  var maxX = start.dx;
  var minY = start.dy;
  var maxY = start.dy;
  for (final p in points) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }

  final lineH = _lineHeightNorm(canvasSize);
  final underH = _underlineHeightNorm(canvasSize);
  final widthNorm = ((maxX - minX) / w).clamp(kMinMarkupWidth, 1.0);
  final heightSpanNorm = (maxY - minY) / h;
  final singleLine = heightSpanNorm < lineH * kMultiLineFactor;

  // Ancla Y: punto de inicio (donde el usuario apoyó) suavizado con la media.
  final anchorYPx = (start.dy * 0.65) + (_meanY(points) * 0.35);
  final anchorY = anchorYPx / h;

  if (tool == AnnotationTool.underline) {
    // Trazo fino justo bajo la línea de texto.
    final top = singleLine
        ? anchorY + (lineH * 0.42)
        : (maxY / h) - underH;
    return _clampToPage(
      MarkupRect(
        x: minX / w,
        y: top,
        width: widthNorm,
        height: underH,
      ),
    );
  }

  // Highlight
  if (singleLine) {
    return _clampToPage(
      MarkupRect(
        x: minX / w,
        y: anchorY - (lineH / 2),
        width: widthNorm,
        height: lineH,
      ),
    );
  }

  // Multilínea: caja que cubre el área recorrida, con un poco de margen.
  final pad = lineH * 0.15;
  return _clampToPage(
    MarkupRect(
      x: minX / w,
      y: (minY / h) - pad,
      width: widthNorm,
      height: heightSpanNorm + pad * 2,
    ),
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
