import 'dart:ui';

import '../core/utils/safe_clamp.dart';

/// Geometría compartida del sello de firma (overlay + exportación).
///
/// Los offsets `offsetX/Y` se interpretan sobre el área útil
/// `(pageSize - stampSize)`, igual en pantalla y en el PDF exportado.
abstract final class SignatureStampGeometry {
  static const double widthFactor = 0.34;
  static const double heightOverWidth = 0.58;

  /// Ancho de referencia histórico del overlay (páginas ~576 px).
  static const double referenceStampWidth = 196;

  static bool isUsablePageSize(Size pageSize) {
    return pageSize.width.isFinite &&
        pageSize.height.isFinite &&
        pageSize.width >= 1 &&
        pageSize.height >= 1;
  }

  static Size stampSizeFor(Size pageSize) {
    if (!isUsablePageSize(pageSize)) {
      return const Size(1, 1);
    }
    final width = safeClamp(pageSize.width * widthFactor, 1.0, pageSize.width);
    final height =
        safeClamp(width * heightOverWidth, 1.0, pageSize.height.toDouble());
    return Size(width, height);
  }

  static double maxLeft(Size pageSize) {
    final stamp = stampSizeFor(pageSize);
    return safeClamp(pageSize.width - stamp.width, 0.0, pageSize.width);
  }

  static double maxTop(Size pageSize) {
    final stamp = stampSizeFor(pageSize);
    return safeClamp(pageSize.height - stamp.height, 0.0, pageSize.height);
  }

  static Offset positionFor({
    required Size pageSize,
    required double offsetX,
    required double offsetY,
  }) {
    final left = safeClamp(offsetX, 0.0, 1.0) * maxLeft(pageSize);
    final top = safeClamp(offsetY, 0.0, 1.0) * maxTop(pageSize);
    return Offset(left, top);
  }
}
