import 'dart:convert';
import 'dart:math' as math;
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

/// Arrastre mínimo (px) para confirmar un trazo de marcado/subrayado.
const double kStrokeCommitPx = 8.0;

/// Muestreo del path en pantalla (evita saturar sin perder forma).
const double kStrokeSamplePx = 1.5;

/// Grosor visual del resaltador (estilo Samsung Notes).
const double kHighlightStrokePx = 22.0;

/// Grosor visual del subrayado a mano alzada.
const double kUnderlineStrokePx = 3.5;

/// Máximo de puntos por trazo al persistir.
const int kMaxInkPoints = 400;

/// Serializa trazos normalizados (0–1) a JSON.
String encodeAnnotationInk(List<List<List<double>>> strokes) {
  return jsonEncode(strokes);
}

/// Decodifica ink JSON tolerante a datos corruptos.
List<List<List<double>>> decodeAnnotationInk(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .map<List<List<double>>>((stroke) {
          if (stroke is! List) return <List<double>>[];
          final points = <List<double>>[];
          for (final point in stroke) {
            if (point is! List || point.length < 2) continue;
            if (point[0] is! num || point[1] is! num) continue;
            final x = (point[0] as num).toDouble();
            final y = (point[1] as num).toDouble();
            if (!x.isFinite || !y.isFinite) continue;
            points.add([
              x.clamp(0.0, 1.0).toDouble(),
              y.clamp(0.0, 1.0).toDouble(),
            ]);
          }
          return points;
        })
        .where((stroke) => stroke.length >= 2)
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

double strokeWidthPxForTool(AnnotationTool tool) {
  return switch (tool) {
    AnnotationTool.highlight => kHighlightStrokePx,
    AnnotationTool.underline => kUnderlineStrokePx,
    _ => kUnderlineStrokePx,
  };
}

double pathLengthPx(List<Offset> points) {
  if (points.length < 2) return 0;
  var len = 0.0;
  for (var i = 1; i < points.length; i++) {
    len += (points[i] - points[i - 1]).distance;
  }
  return len;
}

/// True si el gesto es lo bastante largo para no ser un toque accidental.
bool isStrokeCommitWorthy(List<Offset> points) {
  if (points.length < 2) return false;
  final travel = pathLengthPx(points);
  final span = (points.last - points.first).distance;
  return travel >= kStrokeCommitPx || span >= kStrokeCommitPx;
}

/// Convierte puntos de pantalla a un trazo normalizado (0–1).
///
/// Devuelve `null` si el gesto no es válido.
List<List<double>>? normalizePixelStroke({
  required Size canvasSize,
  required List<Offset> points,
}) {
  final w = canvasSize.width;
  final h = canvasSize.height;
  if (w <= 0 || h <= 0 || !isStrokeCommitWorthy(points)) return null;

  final sampled = <List<double>>[];
  for (final p in points) {
    final next = [
      (p.dx / w).clamp(0.0, 1.0).toDouble(),
      (p.dy / h).clamp(0.0, 1.0).toDouble(),
    ];
    if (sampled.isNotEmpty) {
      final prev = sampled.last;
      final dx = next[0] - prev[0];
      final dy = next[1] - prev[1];
      // ~0.5 px en una página típica de 800px de alto.
      if (math.sqrt(dx * dx + dy * dy) < 0.0006) continue;
    }
    sampled.add(next);
  }

  if (sampled.length < 2) return null;
  return _downsample(sampled, kMaxInkPoints);
}

/// Bounding box normalizado del trazo, con margen según el grosor de la herramienta.
MarkupRect? boundingRectForStroke({
  required AnnotationTool tool,
  required Size canvasSize,
  required List<List<double>> stroke,
}) {
  if (stroke.isEmpty) return null;
  final w = canvasSize.width;
  final h = canvasSize.height;
  if (w <= 0 || h <= 0) return null;

  var minX = stroke.first[0];
  var maxX = stroke.first[0];
  var minY = stroke.first[1];
  var maxY = stroke.first[1];
  for (final p in stroke) {
    if (p[0] < minX) minX = p[0];
    if (p[0] > maxX) maxX = p[0];
    if (p[1] < minY) minY = p[1];
    if (p[1] > maxY) maxY = p[1];
  }

  final padX = (strokeWidthPxForTool(tool) * 0.55) / w;
  final padY = (strokeWidthPxForTool(tool) * 0.55) / h;
  final left = (minX - padX).clamp(0.0, 1.0);
  final top = (minY - padY).clamp(0.0, 1.0);
  final right = (maxX + padX).clamp(0.0, 1.0);
  final bottom = (maxY + padY).clamp(0.0, 1.0);
  final width = (right - left).clamp(0.01, 1.0);
  final height = (bottom - top).clamp(0.006, 1.0);

  return MarkupRect(
    x: left > 1 - width ? 1 - width : left,
    y: top > 1 - height ? 1 - height : top,
    width: width,
    height: height,
  );
}

List<List<double>> _downsample(List<List<double>> points, int maxPoints) {
  if (points.length <= maxPoints) return points;
  if (maxPoints < 2) return points.sublist(0, points.length.clamp(0, 2));

  final sampled = <List<double>>[points.first];
  final lastIndex = points.length - 1;
  for (var i = 1; i < maxPoints - 1; i++) {
    final index = ((i * lastIndex) / (maxPoints - 1)).round();
    sampled.add(points[index]);
  }
  sampled.add(points.last);
  return sampled;
}
