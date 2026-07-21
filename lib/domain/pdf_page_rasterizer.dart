import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

/// Resultado de rasterizar una página PDF a PNG.
class PdfPageRaster {
  const PdfPageRaster({
    required this.pngBytes,
    required this.width,
    required this.height,
    required this.pageWidthPts,
    required this.pageHeightPts,
  });

  final Uint8List pngBytes;
  final int width;
  final int height;

  /// Ancho de la página en puntos PDF (72 dpi).
  final double pageWidthPts;

  /// Alto de la página en puntos PDF (72 dpi).
  final double pageHeightPts;
}

/// Rasteriza una [PdfPage] de pdfrx a PNG (BGRA → ui.Image → PNG).
///
/// [scale] multiplica el tamaño en puntos (p. ej. 1.6 ≈ 115 dpi).
Future<PdfPageRaster> rasterizePdfPage(
  PdfPage page, {
  double scale = 1.6,
}) async {
  final pageW = page.width;
  final pageH = page.height;
  if (!pageW.isFinite ||
      !pageH.isFinite ||
      pageW < 1 ||
      pageH < 1 ||
      !scale.isFinite ||
      scale <= 0) {
    throw StateError('Invalid PDF page size for rasterization');
  }

  final rendered = await page.render(
    fullWidth: pageW * scale,
    fullHeight: pageH * scale,
    backgroundColor: 0xffffffff,
  );
  if (rendered == null) {
    throw StateError('PDF page render returned null');
  }

  try {
    final image = await rendered.createImage();
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Failed to encode PDF page as PNG');
      }
      return PdfPageRaster(
        pngBytes: byteData.buffer.asUint8List(),
        width: image.width,
        height: image.height,
        pageWidthPts: pageW,
        pageHeightPts: pageH,
      );
    } finally {
      image.dispose();
    }
  } finally {
    rendered.dispose();
  }
}
