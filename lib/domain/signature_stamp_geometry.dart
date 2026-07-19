import 'dart:ui';

/// Geometría compartida del sello de firma (overlay + exportación).
///
/// Los offsets `offsetX/Y` se interpretan sobre el área útil
/// `(pageSize - stampSize)`, igual en pantalla y en el PDF exportado.
abstract final class SignatureStampGeometry {
  static const double widthFactor = 0.34;
  static const double heightOverWidth = 0.58;

  /// Ancho de referencia histórico del overlay (páginas ~576 px).
  static const double referenceStampWidth = 196;

  static Size stampSizeFor(Size pageSize) {
    final width = (pageSize.width * widthFactor).clamp(1.0, pageSize.width);
    final height =
        (width * heightOverWidth).clamp(1.0, pageSize.height.toDouble());
    return Size(width.toDouble(), height.toDouble());
  }

  static double maxLeft(Size pageSize) {
    final stamp = stampSizeFor(pageSize);
    return (pageSize.width - stamp.width).clamp(0.0, pageSize.width);
  }

  static double maxTop(Size pageSize) {
    final stamp = stampSizeFor(pageSize);
    return (pageSize.height - stamp.height).clamp(0.0, pageSize.height);
  }

  static Offset positionFor({
    required Size pageSize,
    required double offsetX,
    required double offsetY,
  }) {
    final left = offsetX.clamp(0.0, 1.0) * maxLeft(pageSize);
    final top = offsetY.clamp(0.0, 1.0) * maxTop(pageSize);
    return Offset(left.toDouble(), top.toDouble());
  }
}
