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

/// Alturas típicas de una línea de texto en fracción de página.
const double kMarkupLineHeight = 0.022;
const double kUnderlineStrokeHeight = 0.010;
const double kTapMarkupWidth = 0.10;
const double kMinMarkupWidth = 0.012;
const double kDragCommitPx = 4.0;

/// Calcula el rectángulo de marcado/subrayado a partir del gesto.
///
/// - Arrastre horizontal: sigue el trazo en X y centra en Y media (una línea).
/// - Arrastre con altura clara: caja eje-alineada (varias líneas).
/// - Toque: marca corta centrada en el punto (sin el blob fijo del 34%).
MarkupRect computeMarkupRect({
  required AnnotationTool tool,
  required Size canvasSize,
  required Offset start,
  required Offset end,
  required bool fromDrag,
}) {
  assert(tool.isMarkup);

  final w = canvasSize.width;
  final h = canvasSize.height;
  if (w <= 0 || h <= 0) {
    return const MarkupRect(x: 0, y: 0, width: kMinMarkupWidth, height: kMarkupLineHeight);
  }

  final dx = (end.dx - start.dx).abs();
  final dy = (end.dy - start.dy).abs();
  final isTap = !fromDrag || (dx < kDragCommitPx && dy < kDragCommitPx);

  if (isTap) {
    final heightNorm =
        tool == AnnotationTool.underline ? kUnderlineStrokeHeight : kMarkupLineHeight;
    final widthNorm = kTapMarkupWidth;
    return MarkupRect(
      x: (start.dx / w) - (widthNorm / 2),
      y: (start.dy / h) - (heightNorm / 2),
      width: widthNorm,
      height: heightNorm,
    );
  }

  final leftPx = start.dx < end.dx ? start.dx : end.dx;
  final topPx = start.dy < end.dy ? start.dy : end.dy;
  final widthNorm = (dx / w).clamp(kMinMarkupWidth, 1.0);
  final avgYNorm = ((start.dy + end.dy) / 2) / h;
  final heightNormRaw = dy / h;

  // Arrastre casi horizontal → una sola línea centrada en Y media.
  final singleLine = heightNormRaw < kMarkupLineHeight * 1.6;

  if (tool == AnnotationTool.underline) {
    final top = singleLine
        ? avgYNorm + (kMarkupLineHeight * 0.35)
        : (topPx / h) + heightNormRaw - kUnderlineStrokeHeight;
    return MarkupRect(
      x: leftPx / w,
      y: top,
      width: widthNorm,
      height: kUnderlineStrokeHeight,
    );
  }

  // Highlight
  if (singleLine) {
    final height = heightNormRaw < kMarkupLineHeight * 0.45
        ? kMarkupLineHeight
        : heightNormRaw.clamp(kMarkupLineHeight * 0.7, kMarkupLineHeight * 1.6);
    return MarkupRect(
      x: leftPx / w,
      y: avgYNorm - (height / 2),
      width: widthNorm,
      height: height,
    );
  }

  return MarkupRect(
    x: leftPx / w,
    y: topPx / h,
    width: widthNorm,
    height: heightNormRaw.clamp(kMarkupLineHeight, 1.0),
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
  return MarkupRect(
    x: (point.dx / w) - (width / 2),
    y: (point.dy / h) - (height / 2),
    width: width,
    height: height,
  );
}
