import 'dart:math' as math;
import 'dart:ui' show Rect, Size, Offset;

import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart' show PhotoViewControllerValue;

/// Rectángulo de la página PDF tal como se ve dentro del viewport de PhotoView.
///
/// Replica el layout de PhotoView (centrado + `Transform` con escala/posición).
Rect photoViewPageRectInViewport({
  required Size viewportSize,
  required Size pageSize,
  required PhotoViewControllerValue controllerValue,
  Alignment basePosition = Alignment.center,
}) {
  if (viewportSize.width <= 0 ||
      viewportSize.height <= 0 ||
      pageSize.width <= 0 ||
      pageSize.height <= 0) {
    return Rect.zero;
  }

  final scale = controllerValue.scale;
  final hasMeasuredScale = scale != null && scale > 0;
  final effectiveScale = hasMeasuredScale
      ? scale
      : math.min(
          viewportSize.width / pageSize.width,
          viewportSize.height / pageSize.height,
        );
  if (effectiveScale <= 0) {
    return Rect.zero;
  }

  final childWidth = pageSize.width * effectiveScale;
  final childHeight = pageSize.height * effectiveScale;

  final halfWidth = (viewportSize.width - childWidth) / 2;
  final halfHeight = (viewportSize.height - childHeight) / 2;
  final offsetX = halfWidth * (basePosition.x + 1);
  final offsetY = halfHeight * (basePosition.y + 1);

  // Sin escala medida aún, ignorar pan residual para evitar desalineación.
  final pan = hasMeasuredScale ? controllerValue.position : Offset.zero;
  final left = offsetX + pan.dx;
  final top = offsetY + pan.dy;

  return Rect.fromLTWH(left, top, childWidth, childHeight);
}

/// Convierte un punto del viewport a coordenadas locales de la capa de página.
///
/// Los toques en márgenes (letterbox) se proyectan al borde más cercano de la
/// página para que herramientas y selección sigan respondiendo.
Offset viewportPointToPageLocal(Offset viewportPoint, Rect pageRect) {
  if (pageRect.width <= 0 || pageRect.height <= 0) {
    return Offset.zero;
  }
  final dx = (viewportPoint.dx - pageRect.left).clamp(0.0, pageRect.width);
  final dy = (viewportPoint.dy - pageRect.top).clamp(0.0, pageRect.height);
  return Offset(dx, dy);
}
